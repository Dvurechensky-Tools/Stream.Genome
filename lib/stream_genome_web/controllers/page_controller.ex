defmodule StreamGenomeWeb.PageController do
  use StreamGenomeWeb, :controller

  alias StreamGenome.Narrative

  def home(conn, params) do
    locale = normalize_locale(params["lang"])
    copy = StreamGenomeWeb.PageHTML.home_copy(locale)
    search = Narrative.public_search(params["q"] || "")

    render(conn, :home,
      page_title: page_title(search, copy),
      meta_description:
        "Search an expanding atlas of creator lore: memes, phrases, callbacks, conflicts, arcs, evidence fragments, and emotional timelines.",
      brand_name: copy.brand,
      canonical_url: ~p"/?lang=#{locale}",
      locale: locale,
      copy: copy,
      snapshot: Narrative.dashboard_snapshot(),
      search: search
    )
  end

  defp page_title(%{query: ""}, copy), do: copy.brand
  defp page_title(%{query: query}, copy), do: "Search #{query} - #{copy.brand}"

  defp normalize_locale("en"), do: "en"
  defp normalize_locale(_other), do: "ru"
end
