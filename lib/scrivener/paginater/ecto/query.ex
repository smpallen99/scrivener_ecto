defimpl Scrivener.Paginater, for: Ecto.Query do
  import Ecto.Query

  alias Scrivener.{Config, Page}

  @moduledoc false

  @spec paginate(Ecto.Query.t(), Scrivener.Config.t()) :: Scrivener.Page.t()
  def paginate(query, %Config{
        page_size: page_size,
        page_number: page_number,
        module: repo,
        caller: caller,
        options: options
      }) do

    from_bottom = options[:from_bottom]
    total_entries =
      Keyword.get_lazy(options, :total_entries, fn -> total_entries(query, repo, caller) end)

    total_pages = total_pages(total_entries, page_size)
    page_number = page_number(options[:row], from_bottom, %{
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries,
      page_size: page_size})

    offset = offset(from_bottom, total_entries, page_number, page_size, total_pages)
    entries_page_size = page_size(from_bottom, page_number, total_entries, page_size)

    %Page{
      page_size: page_size,
      page_number: page_number,
      entries: entries(query, repo, offset, page_number, entries_page_size, caller),
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp entries(query, repo, offset, _page_number, page_size, caller) do
    query
    |> limit(^page_size)
    |> offset(^offset)
    |> repo.all(caller: caller)
  end

  defp total_entries(query, repo, caller) do
    total_entries =
      query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> prepare_select
      |> count
      |> repo.one(caller: caller)

    total_entries || 0
  end

  defp prepare_select(
         %{
           group_bys: [
             %Ecto.Query.QueryExpr{
               expr: [
                 {{:., [], [{:&, [], [source_index]}, field]}, [], []} | _
               ]
             }
             | _
           ]
         } = query
       ) do
    query
    |> exclude(:select)
    |> select([x: source_index], struct(x, ^[field]))
  end

  defp prepare_select(query) do
    query
    |> exclude(:select)
  end

  defp count(query) do
    query
    |> subquery
    |> select(count("*"))
  end

  defp total_pages(0, _), do: 1

  defp total_pages(total_entries, page_size) do
    (total_entries / page_size) |> Float.ceil() |> round
  end

  defp page_number(0, _, %{total_pages: total_pages}),
    do: total_pages

  defp page_number(_, _, %{page_number: :last, total_pages: total_pages}),
    do: total_pages

  defp page_number(nil, _, %{page_number: page_number, total_pages: total_pages}),
    do: min(total_pages, page_number)

  defp page_number(row, true, opts) do
    opts.total_pages - div(opts.total_entries - row - 1, opts.page_size)
  end

  defp page_number(row, _, opts) do
    (row - 1)
    |> div(opts.page_size)
    |> Kernel.+(1)
    |> min(opts.total_pages)
  end

  defp page_size(true, 1, page_size, page_size) do
    page_size
  end

  defp page_size(true, 1, total_entries, page_size) do
    rem(total_entries, page_size)
  end

  defp page_size(_, _page_number, _, page_size) do
    page_size
  end

  def offset(true, _total_entries, 1, _page_size, _) do
    0
  end

  def offset(true, total_entries, page_number, page_size, total_pages) do
    offset = total_entries - ((total_pages - page_number + 1) * page_size)
    if offset < 0, do: 0, else: offset
  end

  def offset(_, _total_entries, page_number, page_size, _) do
    page_size * (page_number - 1)
  end
end
