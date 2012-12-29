<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:template match="/">
        <html>
            <h1>Item overview</h1>
            <ul>
                <xsl:for-each select="//Item">
                    <li>
                        <xsl:value-of select="@name"/>: <xsl:value-of select="."/>
                    </li>
                </xsl:for-each>
            </ul>
        </html>
    </xsl:template>
</xsl:stylesheet>