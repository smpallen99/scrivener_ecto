defmodule Scrivener.Paginator.Ecto.QueryTest do
  use Scrivener.Ecto.TestCase

  alias Scrivener.Ecto.{Comment, KeyValue, Post}

  defp create_posts do
    unpublished_post =
      %Post{
        title: "Title unpublished",
        body: "Body unpublished",
        published: false
      }
      |> Scrivener.Ecto.Repo.insert!()

    Enum.map(1..2, fn i ->
      %Comment{
        body: "Body #{i}",
        post_id: unpublished_post.id
      }
      |> Scrivener.Ecto.Repo.insert!()
    end)

    Enum.map(1..6, fn i ->
      %Post{
        title: "Title #{i}",
        body: "Body #{i}",
        published: true
      }
      |> Scrivener.Ecto.Repo.insert!()
    end)
  end

  defp create_key_values do
    Enum.map(1..10, fn i ->
      %KeyValue{
        key: "key_#{i}",
        value: rem(i, 2) |> to_string
      }
      |> Scrivener.Ecto.Repo.insert!()
    end)
  end

  describe "paginate" do
    test "paginates an unconstrained query" do
      create_posts()

      page = Post |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "page information is correct with no results" do
      page = Post |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 0
      assert page.total_pages == 1
    end

    test "uses defaults from the repo" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.entries == Enum.take(posts, 5)
      assert page.total_entries == 6
      assert page.total_pages == 2
    end

    test "it handles preloads" do
      create_posts()

      page =
        Post
        |> Post.published()
        |> preload(:comments)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_pages == 2
    end

    test "it handles complex selects" do
      create_posts()

      page =
        Post
        |> join(:left, [p], c in assoc(p, :comments))
        |> group_by([p], p.id)
        |> select([p], sum(p.id))
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "it handles complex order_by" do
      create_posts()

      page =
        Post
        |> select([p], fragment("? as aliased_title", p.title))
        |> order_by([p], fragment("aliased_title"))
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "can be provided the current page and page size as a params map" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(%{"page" => "2", "page_size" => "3"})

      assert page.page_size == 3
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 3)
      assert page.total_pages == 2
    end

    test "can be provided the current page and page size as options" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page: 2, page_size: 3)

      assert page.page_size == 3
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 3)
      assert page.total_pages == 2
    end

    test "can be provided the caller as options" do
      create_posts()
      parent = self()

      task =
        Task.async(fn ->
          Post
          |> Scrivener.Ecto.Repo.paginate(caller: parent)
        end)

      page = Task.await(task)

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "can be provided the caller as a map" do
      create_posts()

      parent = self()

      task =
        Task.async(fn ->
          Post
          |> Scrivener.Ecto.Repo.paginate(%{"caller" => parent})
        end)

      page = Task.await(task)

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 7
      assert page.total_pages == 2
    end

    test "will respect the max_page_size configuration" do
      create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(%{"page" => "1", "page_size" => "20"})

      assert page.page_size == 10
    end

    test "will respect the total_entries configuration" do
      create_posts()

      config = %Scrivener.Config{
        module: Scrivener.Ecto.Repo,
        page_number: 2,
        page_size: 4,
        options: [total_entries: 130]
      }

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(config)

      assert page.total_entries == 130
    end

    test "will respect total_entries passed to paginate" do
      create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(options: [total_entries: 130])

      assert page.total_entries == 130
    end

    test "will use total_pages if page_numer is too large" do
      posts = create_posts()

      config = %Scrivener.Config{
        module: Scrivener.Ecto.Repo,
        page_number: 2,
        page_size: length(posts),
        options: []
      }

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(config)

      assert page.page_number == 1
      assert page.entries == posts
    end

    test "can be used on a table with any primary key" do
      create_key_values()

      page =
        KeyValue
        |> KeyValue.zero()
        |> Scrivener.Ecto.Repo.paginate(page_size: 2)

      assert page.total_entries == 5
      assert page.total_pages == 3
    end

    test "can be used with a group by clause" do
      create_posts()

      page =
        Post
        |> join(:left, [p], c in assoc(p, :comments))
        |> group_by([p], p.id)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "can be used with a group by clause on field other than id" do
      create_posts()

      page =
        Post
        |> group_by([p], p.body)
        |> select([p], p.body)
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 7
    end

    test "can be used with a group by clause on field on joined table" do
      create_posts()

      page =
        Post
        |> join(:inner, [p], c in assoc(p, :comments))
        |> group_by([p, c], c.body)
        |> select([p, c], {c.body, count("*")})
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 2
    end

    test "can be used with compound group by clause" do
      create_posts()

      page =
        Post
        |> join(:inner, [p], c in assoc(p, :comments))
        |> group_by([p, c], [c.body, p.title])
        |> select([p, c], {c.body, p.title, count("*")})
        |> Scrivener.Ecto.Repo.paginate()

      assert page.total_entries == 2
    end

    test "can be provided a Scrivener.Config directly" do
      posts = create_posts()

      config = %Scrivener.Config{
        module: Scrivener.Ecto.Repo,
        page_number: 2,
        page_size: 4,
        options: []
      }

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(config)

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 4)
      assert page.total_pages == 2
    end

    test "can be provided a keyword directly" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(module: Scrivener.Ecto.Repo, page: 2, page_size: 4)

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 4)
      assert page.total_pages == 2
    end

    test "can be provided a map directly" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.paginate(%{"module" => Scrivener.Ecto.Repo, "page" => 2, "page_size" => 4})

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.entries == Enum.drop(posts, 4)
      assert page.total_pages == 2
    end

    test "can paginate page 1 from the bottom" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page: 1, options: [from_bottom: true])

      assert page.page_size == 5
      assert page.page_number == 1
      assert page.total_entries == 6
      assert page.total_pages == 2
      assert page.entries |> length == 1
      assert page.entries == posts |> Enum.take(1)
    end

    test "can paginate last page from the bottom" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page: 2, page_size: 4, options: [from_bottom: true])

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.total_entries == 6
      assert page.total_pages == 2
      assert page.entries |> length == 4
      assert page.entries == posts |> Enum.drop(2)
    end

    test "can paginate 2nd last page from the bottom" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page: 2, page_size: 2, options: [from_bottom: true])

      assert page.page_size == 2
      assert page.page_number == 2
      assert page.total_entries == 6
      assert page.total_pages == 3
      assert page.entries |> length == 2
      assert page.entries == posts |> Enum.drop(2) |> Enum.take(2)
    end

    test "gets last page for option row 0" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page_size: 4, options: [row: 0, from_bottom: true])

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.total_entries == 6
      assert page.total_pages == 2
      assert page.entries |> length == 4
      assert page.entries == posts |> Enum.drop(2)
    end

    test "gets first page for option row 1" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page_size: 4, options: [row: 1, from_bottom: true])

      assert page.page_size == 4
      assert page.page_number == 1
      assert page.total_entries == 6
      assert page.total_pages == 2
      assert page.entries |> length == 2
      assert page.entries == posts |> Enum.take(2)
    end

    test "gets first page for option row 2" do
      posts = create_posts()

      page =
        Post
        |> Post.published()
        |> Scrivener.Ecto.Repo.paginate(page_size: 4, options: [row: 3, from_bottom: true])

      assert page.page_size == 4
      assert page.page_number == 2
      assert page.total_entries == 6
      assert page.total_pages == 2
      assert page.entries |> length == 4
      assert page.entries == posts |> Enum.drop(2)
    end
  end
end
