---
layout: post
title: "Building an E-commerce API with Modern Rails"
subtitle: "A practical API-only Rails design for a small storefront"
author: Somaditya Basak
tags: [ruby, rails, api, ecommerce, programming]
---

Rails is productive for JSON APIs as well as server-rendered applications. This walkthrough sketches a small storefront API with a product catalog, a customer's cart, and a checkout that snapshots prices and reserves inventory safely.

The examples use current Rails conventions and PostgreSQL. They focus on the application boundary and core persistence logic; a production shop also needs authentication, payment-provider integration, observability, and operational safeguards.

## Start with an API-only application

Create an API-only Rails application with PostgreSQL:

```sh
rails new storefront --api --database=postgresql
cd storefront
bin/rails db:create
```

API-only mode uses `ActionController::API` and avoids browser-oriented middleware that an API may not need. Add an authentication solution appropriate for your clients before exposing customer-specific endpoints. In the controller examples below, `current_user` represents the authenticated customer supplied by that layer; it is not provided by Rails automatically.

## Model the commerce data

A useful first model separates catalog data, mutable cart lines, and immutable order-line snapshots:

- `Product` stores the current name, price in cents, currency, and available inventory.
- `Cart` belongs to a customer and owns `CartItem` rows.
- `Order` belongs to a customer and owns `OrderItem` rows created at checkout.
- `OrderItem` stores the product name and unit price at purchase time, so later catalog edits do not rewrite order history.

Store money as integer minor units (for example, cents), not floating-point values. A simplified migration for the catalog and inventory might look like this:

```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.integer :stock, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_check_constraint :products, "price_cents >= 0", name: "products_price_nonnegative"
    add_check_constraint :products, "stock >= 0", name: "products_stock_nonnegative"
  end
end
```

Create equivalent migrations for carts, cart items, orders, and order items. Add foreign keys, non-null constraints, and unique indexes where the domain requires them. For example, a cart should have at most one line per product, and an order can carry a unique idempotency key for a customer:

```ruby
add_index :cart_items, [:cart_id, :product_id], unique: true
add_index :orders, [:user_id, :idempotency_key], unique: true
```

The database constraints matter even when the models validate the same rules: requests can arrive concurrently, and application-level checks alone cannot enforce uniqueness.

Associations keep the domain readable:

```ruby
class Product < ApplicationRecord
  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error

  validates :name, :sku, :currency, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

class Cart < ApplicationRecord
  belongs_to :user
  has_many :items, class_name: "CartItem", dependent: :destroy
end

class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end

class Order < ApplicationRecord
  belongs_to :user
  has_many :items, class_name: "OrderItem", dependent: :restrict_with_error

  validates :idempotency_key, presence: true, uniqueness: { scope: :user_id }
end

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :product_name, :currency, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

The `user`, `product_name`, and other snapshot columns above should be created by the migrations along with their foreign keys and indexes.

## Define versioned endpoints

Keep API routes namespaced so the external contract can evolve deliberately:

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :products, only: [:index]
    resource :cart, only: [:show] do
      resources :items, only: [:create], controller: "cart_items"
    end
    post "checkout", to: "checkouts#create"
  end
end
```

This produces endpoints such as `GET /api/v1/products`, `GET /api/v1/cart`, `POST /api/v1/cart/items`, and `POST /api/v1/checkout`.

## Keep the catalog read-only to clients

A catalog endpoint should select only active products, limit the result size, and serialize only fields intended for the API:

```ruby
class Api::V1::ProductsController < ActionController::API
  def index
    products = Product.where(active: true).order(:name).limit(50)

    render json: {
      data: products.map do |product|
        {
          id: product.id,
          name: product.name,
          sku: product.sku,
          price_cents: product.price_cents,
          currency: product.currency
        }
      end
    }
  end
end
```

For a real catalog, add pagination and filtering rather than increasing the limit without bound. Avoid exposing internal columns just because they are present on an Active Record object.

## Accept cart input narrowly

Never let a client set a price, stock level, customer ID, or order total. Permit only the fields the endpoint actually accepts:

```ruby
class Api::V1::CartItemsController < ActionController::API
  def create
    attributes = params.require(:item).permit(:product_id, :quantity)
    product = Product.find(attributes.fetch(:product_id))
    quantity = Integer(attributes.fetch(:quantity))
    raise ArgumentError, "quantity must be positive" unless quantity.positive?

    cart = current_user.cart
    cart.with_lock do
      item = cart.items.find_or_initialize_by(product: product)
      item.quantity = item.quantity.to_i + quantity
      item.save!
    end

    render json: { data: { product_id: product.id, quantity: item.quantity } },
           status: :created
  rescue ArgumentError, KeyError
    render json: { error: "A positive integer quantity and product_id are required" },
           status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product not found" }, status: :not_found
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages },
           status: :unprocessable_entity
  end
end
```

This example assumes the authentication layer supplies `current_user` and the application creates or retrieves that customer's open cart. The cart lock serializes simultaneous edits to its lines; the database unique index on `(cart_id, product_id)` remains the final protection against duplicate lines. A production endpoint should also enforce request-size limits and rate limits.

## Make checkout one database transaction

Checkout is more than creating an order. It must use trusted product prices, ensure stock is available, decrement inventory, and preserve a price snapshot. These writes belong in one database transaction:

```ruby
class Checkout
  class OutOfStock < StandardError; end
  class CartNotOpen < StandardError; end
  class EmptyCart < StandardError; end

  def self.call(user:, idempotency_key:)
    cart = user.cart

    cart.with_lock do
      existing = user.orders.find_by(idempotency_key: idempotency_key)
      return existing if existing
      raise CartNotOpen unless cart.status == "open"

      items = cart.items.includes(:product).order(:id).to_a
      raise EmptyCart if items.empty?

      product_ids = items.map(&:product_id)
      products = Product.where(id: product_ids).order(:id).lock.index_by(&:id)

      order = user.orders.create!(
        idempotency_key: idempotency_key,
        status: "pending",
        total_cents: 0,
        currency: items.first.product.currency
      )

      total_cents = 0

      items.each do |item|
        product = products.fetch(item.product_id)
        raise OutOfStock unless product.active? && product.stock >= item.quantity
        raise ArgumentError, "Cart items must use the same currency" unless
          product.currency == order.currency

        product.update!(stock: product.stock - item.quantity)
        order.items.create!(
          product: product,
          product_name: product.name,
          quantity: item.quantity,
          unit_price_cents: product.price_cents,
          currency: product.currency
        )
        total_cents += product.price_cents * item.quantity
      end

      order.update!(total_cents: total_cents)
      cart.update!(status: "checked_out")
      order
    end
  end
end
```

`with_lock` wraps the block in a transaction and locks the cart row. Product rows are locked in a stable order so two checkouts competing for the same products serialize their inventory checks. The price and product name copied to each order line come from the database, not request parameters.

The idempotency key lets a client retry a checkout after a network timeout without intentionally creating another order. The unique database index is essential. In a production implementation, handle a unique-key race by loading the already-created order after the transaction rolls back, and scope keys according to the API contract.

The controller can pass the key and expose the resulting order:

```ruby
class Api::V1::CheckoutsController < ActionController::API
  def create
    key = request.headers["Idempotency-Key"]
    return render json: { error: "Idempotency-Key is required" },
                  status: :bad_request if key.blank?

    order = Checkout.call(user: current_user, idempotency_key: key)
    render json: {
      data: {
        id: order.id,
        status: order.status,
        total_cents: order.total_cents,
        currency: order.currency
      }
    }, status: :created
  rescue Checkout::OutOfStock
    render json: { error: "One or more items are no longer available" },
           status: :conflict
  rescue Checkout::CartNotOpen
    render json: { error: "Cart is not open for checkout" }, status: :conflict
  rescue Checkout::EmptyCart
    render json: { error: "Cart is empty" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages },
           status: :unprocessable_entity
  rescue ArgumentError => error
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
```

For clarity, the service omits some production concerns: validating key format and length, selecting the correct active cart, deciding whether a cart may be checked out again, and carefully handling idempotency-key uniqueness races. Those policies should be implemented and covered by database constraints and tests.

## Keep payment providers outside the transaction

Do not call a payment provider while holding database locks. Network calls can be slow or fail after the provider has accepted a charge, leaving the database transaction in an uncertain state.

A common design is to commit an order in a pending-payment state, then enqueue a payment job after commit. For stronger delivery guarantees, write an outbox record in the same transaction as the order and have a worker deliver it with retries. The payment integration should also use an idempotency key with the provider, and the order should transition to paid only after a verified provider response or webhook.

## Test the behavior and the races

Request and model tests should cover at least:

- A client cannot set the product price or order total.
- Adding the same product updates one cart line rather than creating duplicates.
- Checkout snapshots the current price and reduces inventory exactly once.
- An out-of-stock item leaves the cart and inventory unchanged.
- Repeating the same checkout request returns the original order.
- Two simultaneous checkouts cannot sell more units than are in stock.
- A payment timeout or duplicate webhook does not create duplicate charges or orders.

Concurrency tests need a database and test configuration that exercise real row locking; a single-threaded test is not proof against races.

## Wrap-up

Modern Rails gives you routing, parameter handling, Active Record transactions, and locking primitives, but e-commerce correctness still depends on explicit domain rules. Keep client input narrow, let the database enforce invariants, snapshot purchase data, make retries safe, and move external side effects out of database transactions.

For more, see the Rails guides on [API-only applications](https://guides.rubyonrails.org/api_app.html), [Active Record transactions](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html), and [pessimistic locking](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html).
