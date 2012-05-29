module namespace shakes="http://exist-db.org/apps/demo/shakespeare";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../modules/config.xqm";
import module namespace templates="http://exist-db.org/xquery/templates" at "../../modules/templates.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic"
    at "resource:org/exist/xquery/lib/kwic.xql";

declare variable $shakes:SESSION := "shakespeare:results";

(:~
 : Execute a query and pass the result to nested template functions. The annotation
 : %templates:output("model") indicates that we want the output of the function
 : to become the new model for any nested template functions. The templating
 : module copies the current element and its attributes, then continues processing
 : its children.
 :)
declare
    %templates:output("model")
function shakes:query($node as node()*, $model as item()*, $query as xs:string?, $mode as xs:string) {
    session:create(),
    let $hits := shakes:do-query($query, $mode)
    let $store := session:set-attribute($shakes:SESSION, $hits)
    return
        $hits
};

declare function shakes:do-query($queryStr as xs:string?, $mode as xs:string) {
    let $query := shakes:create-query($queryStr, $mode)
    for $hit in collection($config:app-root)//SCENE[ft:query(., $query)]
    order by ft:score($hit) descending
    return $hit
};

(:~
    Read the last query result from the HTTP session and pass it to nested templates
    in the $model parameter.
:)
declare 
    %templates:output("model")
function shakes:from-session($node as node()*, $model as item()*) {
    session:get-attribute($shakes:SESSION)
};

(:~
 : Create a span with the number of items in the current search result.
 : The annotation %templates:output("wrap") tells the templating module
 : to create a new element with the same name and attributes as $node,
 : using the return value of the function as its content.
 :)
declare 
    %templates:output("wrap")
function shakes:hit-count($node as node()*, $model as item()*) {
    count($model)
};

(:~
 : Output the actual search result as a div, using the kwic module to summarize full text matches.
:)
declare 
    %templates:default("start", 1)
function shakes:show-hits($node as node()*, $model as item()*, $start as xs:int) {
    for $hit at $p in subsequence($model, $start, 10)
    let $kwic := kwic:summarize($hit, <config width="40" table="yes"/>, shakes:filter#2)
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
declare %private function shakes:filter($node as node(), $mode as xs:string) as xs:string? {
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
declare function shakes:create-query($queryStr as xs:string?, $mode as xs:string) {
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
