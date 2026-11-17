# Scrivener.Ecto

[![Build Status](https://travis-ci.org/drewolson/scrivener_ecto.svg?branch=master)](https://travis-ci.org/drewolson/scrivener_ecto) [![Hex Version](http://img.shields.io/hexpm/v/scrivener_ecto.svg?style=flat)](https://hex.pm/packages/scrivener_ecto) [![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/scrivener_ecto)

Scrivener.Ecto allows you to paginate your Ecto queries with Scrivener. It gives you useful information such as the total number of pages, the current page, and the current page's entries. It works nicely with Phoenix as well.

First, you'll want to `use` Scrivener in your application's Ecto Repo. This will add a `paginate` function to your Repo. This `paginate` function expects to be called with, at a minimum, an Ecto query. It will then paginate the query and execute it, returning a `Scrivener.Page`. Defaults for `page_size` can be configured when you `use` Scrivener. If no `page_size` is provided, Scrivener will use `10` by default.

You may also want to call `paginate` with a params map along with your query. If provided with a params map, Scrivener will use the values in the keys `"page"` and `"page_size"` before using any configured defaults.

Note: Scrivener.Ecto only supports Ecto backends that allow subqueries (e.g. PostgreSQL).

## Example

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app
  use Scrivener, page_size: 10
end
```

```elixir
defmodule MyApp.Person do
  use Ecto.Schema

  schema "people" do
    field :name, :string
    field :age, :integer

    has_many :friends, MyApp.Person
  end
end
```

```elixir
def index(conn, params) do
  page =
    MyApp.Person
    |> where([p], p.age > 30)
    |> order_by(desc: :age)
    |> preload(:friends)
    |> MyApp.Repo.paginate(params)

  render conn, :index,
    people: page.entries,
    page_number: page.page_number,
    page_size: page.page_size,
    total_pages: page.total_pages,
    total_entries: page.total_entries
end
```

```elixir
page =
  MyApp.Person
  |> where([p], p.age > 30)
  |> order_by(desc: :age)
  |> preload(:friends)
  |> MyApp.Repo.paginate(page: 2, page_size: 5)
```

## Installation

Add `scrivener_ecto` to your `mix.exs` dependencies. Mix starts dependency
applications automatically.

```elixir
[{:scrivener_ecto, "~> 1.0"}]
```

## Development on Elixir 1.20

This fork selects Elixir `1.20.4-otp-29` and Erlang `29.1.2` with asdf's
`.tool-versions`. It uses Ecto 3.14 and retains the custom `from_bottom`, `row`,
and explicit-config `page_number: :last` pagination options.

Tests use PostgreSQL through Postgrex 0.22. With PostgreSQL running locally,
create and migrate the dedicated test database, then run the suite:

```sh
mix deps.get
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
mix test --warnings-as-errors
```

The default database is `scrivener_test`. Set `SCRIVENER_ECTO_DB_USER` to use a
different user from your OS account, and `SCRIVENER_ECTO_DB_PASSWORD` when a
password is required. The existing `mix db.reset` alias drops the test database;
normal setup only requires create/migrate.

Additional checks:

```sh
mix test --cover
mix compile --force --warnings-as-errors
MIX_ENV=test mix compile --force --warnings-as-errors
MIX_ENV=prod mix compile --force --warnings-as-errors
mix dialyzer
mix docs --warnings-as-errors
mix format --check-formatted
```

The grouped-count query matches Ecto's `ByExpr` group expressions. Tests cover
joined and compound groups, ordinary pages, bottom pagination, row lookup,
explicit last-page selection, and empty results.
