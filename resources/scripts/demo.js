
$(document).ready(function() {
    // Enable code highlighting
    $(".code").highlight();
    
    // Enable "Run" buttons
    $(".run").click(function(ev) {
        ev.preventDefault();
        var type = $(this).data("type") || "xml";
        var text = $(this).parent().parent().find(".code").highlight("getText");
        var output = $(this).parent().find(".output");
        var indicator = $(this).parent().find(".load-indicator");
        var query = 
            "<query xmlns=\"http://exist.sourceforge.net/NS/exist\" " +
            "   method=\"json\" start=\"1\" indent=\"yes\">\n" +
            "   <text><![CDATA[" + text + "]]></text>\n" +
            "</query>";
        
        function run() {
            indicator.show();
            output.hide();
            $.ajax({
                url: "/exist/rest/db/",
                type: "POST",
                contentType: "application/xml",
                data: query,
                dataType: "json",
                success: function(result) {
                    indicator.hide();
                    var data;
                    if (Array.isArray(result.data))
                        data = result.data.join("\n");
                    else
                        data = result.data;
                    if (type === "xml") {
                        var pre = document.createElement("div");
                        pre.className = "code";
                        pre.appendChild(document.createTextNode(data));
                        output.html(pre);
                        $(pre).data("language", "xml");
                        $(pre).highlight({ theme: "dawn" });
                    } else
                        output.html(data);
                    output.slideDown(600);
                }
            });
        }
        
        if (output.is(":empty")) {
            run();
        } else {
            output.slideUp(800, function() {
                output.empty();
                run();
            });
        }
    });
});