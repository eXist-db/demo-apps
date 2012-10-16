xquery version "1.0";

module namespace guess="http://exist-db.org/apps/demo/guess";

import module namespace templates="http://exist-db.org/xquery/templates" at "../../modules/templates.xql";

(:~
 :  Template function called by class="guess:init". Generates a random number
 :  and stores it into the session, then calls any nested templates with the
 :  generated number as $model.
 :)
declare function guess:init($node as node(), $model as map(*)) as map(*){
    session:create(),
    let $randSession := session:get-attribute("random")
    let $rand :=
        if ($randSession) then
            $randSession
        else
            guess:random(100)
    return
        map { "random" := $rand }
};

(:~
 :  Evaluate the guessed number, which is passed in as model.
 :)
declare function guess:evaluate-guess($node as node(), $model as map(*), $guess as xs:integer?) {
    let $random := $model("random")
    let $count as xs:integer := session:get-attribute("guesses") + 1
    return (
        session:set-attribute("guesses", $count),
        if (empty($guess)) then
            <p>Please enter your guess!</p>
        else if (xs:int($guess) lt $random) then
            <p>[Guess {$count}]: Your number is too small!</p>
        else if (xs:int($guess) gt $random) then
            <p>[Guess {$count}]: Your number is too large!</p>
        else (
            <p>Congratulations! You guessed the right number with
            {$count} tries. Try again!</p>,
            session:set-attribute("random", ())
        )
    )
};

(:~
 :  Helper function: generate a random integer.
 :
 :  @param $max the generated random will be between 1 and $max
 :)
declare function guess:random($max as xs:integer) as xs:integer
{
    let $r := ceiling(util:random() * $max) cast as xs:integer
    return (
        session:set-attribute("random", $r),
        session:set-attribute("guesses", 0),
        $r
    )
};