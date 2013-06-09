xquery version "1.0";
(: $Id$ :)

(:~
 : Simple XQuery example without HTML templating. The entire app is contained in one file.
:)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../modules/config.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

declare function local:random($max as xs:integer) 
as empty()
{
    let $r := ceiling(util:random() * $max) cast as xs:integer
    return (
        session:set-attribute("random", $r),
        session:set-attribute("guesses", 0)
    )
};

declare function local:guess($guess as xs:integer,
$rand as xs:integer) as element()
{
    let $count := session:get-attribute("guesses") + 1
    return (
        session:set-attribute("guesses", $count),
        if ($guess lt $rand) then
            <p>[Guess {$count}]: Your number is too small!</p>
        else if ($guess gt $rand) then
            <p>[Guess {$count}]: Your number is too large!</p>
        else
            let $newRandom := local:random(100)
            return
                <p>Congratulations! You guessed the right number with
                {$count} tries. Try again!</p>
    )
};

declare function local:main() as node()?
{
    session:create(),
    let $rand := session:get-attribute("random"),
        $guess := xs:integer(request:get-parameter("guess", ()))
    return
		if ($rand) then 
			if ($guess) then
				local:guess($guess, $rand)
			else
				<p>No input!</p>
		else 
		    local:random(100)
};

<html>
    <head>
        <title>Number Guessing</title>
        <style type="text/css">
            body {{ width: 400px; }}
            label {{ width: 120px; display: block; float: left; }}
        </style>
    </head>
    <body>
        <p> 
            <a href="{request:get-context-path()}/apps/eXide/index.html?open={$config:app-root}/examples/web/guess.xql" 
                target="eXide">View/edit source</a>
        </p>
        <h1>Guess a Number</h1>
        <form action="{session:encode-url(request:get-uri())}">
            <div>
                <label for="guess">Number:</label>
                <input type="text" name="guess" size="3" autofocus="autofocus" required="required"/>
            </div>
            <input type="submit"/>
        </form>
        { local:main() }
        <p>
            <a href="index.html">Back to examples</a>
        </p>
    </body>
</html>
