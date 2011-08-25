module namespace demo="http://exist-db.org/apps/demo";

declare function demo:hello($node as node()*, $params as element(parameters)?, $model as item()*) {
    <span>Hello World!</span>
};

declare function demo:multiply($node as node()*, $params as element(parameters)?, $model as item()*) {
    let $p1 := $params/param[@name = "n1"]/@value
    let $p2 := $params/param[@name = "n2"]/@value
    return
        number($p1) * number($p2)
};