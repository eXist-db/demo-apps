module namespace shakes="http://exist-db.org/apps/demo/shakespeare";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../modules/config.xqm";
import module namespace templates="http://exist-db.org/xquery/templates" at "../../modules/templates.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic"
    at "resource:org/exist/xquery/lib/kwic.xql";

declare variable $shakes:CALLBACK := util:function(xs:QName("shakes:filter"), 2);
declare variable $shakes:SESSION := "shakespeare:results";

(:~
    Execute the query. The search results are not output immediately. Instead they
    are passed to nested templates through the $model parameter.
:)
declare function shakes:query($node as node()*, $params as element(parameters)?, $model as item()*) {
    session:create(),
    let $query := shakes:create-query()
    let $hits :=
        for $hit in collection($config:app-root)//SCENE[ft:query(., $query)]
        order by ft:score($hit) descending
        return $hit
    let $store := session:set-attribute($shakes:SESSION, $hits)
    return
        (: Process nested templates :)
        <div id="results">{ templates:process($node/*, $hits) }</div>
};

(:~
    Read the last query result from the HTTP session and pass it to nested templates
    in the $model parameter.
:)
declare function shakes:from-session($node as node()*, $params as element(parameters)?, $model as item()*) {
    let $hits := session:get-attribute($shakes:SESSION)
    return
        templates:process($node/*, $hits)
};

(:~
    Create a span with the number of items in the current search result.
:)
declare function shakes:hit-count($node as node()*, $params as element(parameters)?, $model as item()*) {
    <span id="hit-count">{ count($model) }</span>
};

(:~
    Output the actual search result as a div, using the kwic module to summarize full text matches.
:)
declare function shakes:show-hits($node as node()*, $params as element(parameters)?, $model as item()*) {
    let $start := number(request:get-parameter("start", 1))
    for $hit at $p in subsequence($model, $start, 10)
    let $kwic := kwic:summarize($hit, <config width="40" table="yes"/>, $shakes:CALLBACK)
    return
        <div class="scene">
            <h3>{$hit/ancestor::PLAY/TITLE/text()}</h3>
            <h4>{$hit/TITLE/text()}</h4>
            <span class="number">{$start + $p - 1}</span>
            <table>{ $kwic }</table>
        </div>
};

(:~
    Callback function called from the kwic module.
:)
declare function shakes:filter($node as node(), $mode as xs:string) as xs:string? {
  if ($node/parent::SPEAKER or $node/parent::STAGEDIR) then 
      ()
  else if ($mode eq 'before') then 
      concat($node, ' ')
  else 
      concat(' ', $node)
};

(:~
    Helper function: create a lucene query from the user input
:)
declare function shakes:create-query() {
    let $queryStr := request:get-parameter("query", ())
    let $mode := request:get-parameter("mode", "all")
    return
        <query>
        {
            if ($mode eq 'any') then
                for $term in tokenize($queryStr, '\s')
                return
                    <term occur="should">{$term}</term>
            else if ($mode eq 'all') then
                for $term in tokenize($queryStr, '\s')
                return
                    <term occur="must">{$term}</term>
            else if ($mode eq 'phrase') then
                <phrase>{$queryStr}</phrase>
            else
                <near>{$queryStr}</near>
        }
        </query>
};
