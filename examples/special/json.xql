xquery version "1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json="http://www.json.org";

(: Switch to JSON serialization :)
declare option output:method "json";
declare option output:media-type "text/javascript";

(:~
 : Travers the sub collections of the specified root collection.
 :
 : @param $root the path of the root collection to process
 :)
declare function local:sub-collections($root as xs:string) {
    let $children := xmldb:get-child-collections($root)
    for $child in $children
    return
        <children json:array="true">
		{ local:collections(concat($root, '/', $child), $child) }
		</children>
};

(:~
 : Generate metadata for a collection. Recursively process sub collections.
 :
 : @param $root the path to the collection to process
 : @param $label the label (name) to display for this collection
 :)
declare function local:collections($root as xs:string, $label as xs:string) {
    (
        <title>{$label}</title>,
        <isFolder json:literal="true">true</isFolder>,
        <key>{$root}</key>,
        if (sm:has-access($root, "rx")) then
            local:sub-collections($root)
        else
            ()
    )
};

let $collection := request:get-parameter("root", "/db/apps")
return
    <collection json:array="true">
    {local:collections($collection, replace($collection, "^.*/([^/]+$)", "$1"))}
    </collection>