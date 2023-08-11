function Find-PSFHCryptoRssRepositories {
    <#
    .SYNOPSIS
    Retrieves repository URLs from a specified text file.

    .DESCRIPTION
    This function reads a text file and retrieves the repository URLs listed within the file.

    .PARAMETER ListPath
    Specifies the path to the text file containing repository URLs.
    
    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Find-PSFHCryptoRssRepositories -ListPath "C:\Repositories.txt"
    Retrieves and displays the repository URLs listed in the specified text file.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [ValidatePattern('.*\.txt$')]
        [string]$ListPath
    )

    try {
        # Retrieve repository URLs from the text file
        $repositoryUrls = Get-Content -Path $ListPath

        # Output the retrieved repository URLs
        return $repositoryUrls
    }
    catch {
        # Handle errors
        Write-information "Failed to retrieve repository URLs from '$ListPath': $($_.Exception.Message)" -InformationAction Continue
        
        break
    }
}

function Get-PSFHFeedInfo {
    <#
    .SYNOPSIS
    Retrieves information about an RSS or Atom feed from a specified URL.

    .DESCRIPTION
    This function retrieves the feed type (RSS or Atom) and feed version for the specified URL.

    .PARAMETER Url
    Specifies the URL of the feed.

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Get-PSFHFeedInfo -Url "https://example.com/feed"
    Retrieves and displays information about the RSS or Atom feed from the specified URL.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Url
    )

    try {
        # Get the feed type (RSS or Atom)
        $feedType = Get-PSFHFeedType -Url $Url -XMLReader

        if (-not ($feedType -eq 'unknown')) {

            write-verbose $feedType
    
            # Get the feed version
            $feedVersion = Get-PSFHFeedVersion -Url $Url -FeedType $feedType

        }
        else {

            $feedVersion = 'unknown'

        }       

        $feed = Get-PSFHFeed -Url $Url
        $feedNewsCount = Invoke-PSFHFeedAnalysis -Feed $feed

        $LastPublishedDate = Invoke-PSFHFeedAnalysis -Feed $feed -LastPublishedDate

        $isoDateTime = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        Write-Verbose "ISO 8601 format with time: $isoDateTime"

        #$feed        
        #$feedNewsCount = Invoke-PSFHFeedAnalysis -Feed

        # Create a custom object with feed information
        return [PSCustomObject]@{
            'Url'            = $Url
            'FeedType'       = $feedType
            'FeedVersion'    = $feedVersion
            'News count'     = $FeedNewsCount
            'Published date' = $LastPublishedDate
            'Test date'      = $isoDateTime
        }
    }
    catch {
        # Handle errors
        Write-information "Failed to retrieve feed info for '$Url': $($_.Exception.Message)" -InformationAction Continue
        break
    }
}

function Get-PSFHFeedType {
    <#
    .SYNOPSIS
    Retrieves the type (RSS or Atom) of a feed from a specified URL.

    .DESCRIPTION
    This function determines the type of feed (RSS or Atom) based on the response content type or the XML elements present in the feed.

    .PARAMETER Url
    Specifies the URL of the feed.

    .PARAMETER XMLReader
    Specifies whether to use XmlReader for parsing XML. Default is False.

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Get-PSFHFeedType -Url "https://example.com/feed"
    Retrieves and returns the type of the feed from the specified URL.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory = $false)]
        [switch]$XMLReader
    )

    # Validate input
    #if (-not (Test-Connection -ComputerName $Url -Quiet)) {
    #    Write-Error "Invalid URL: $Url"
    #    return
    #}

    # Determine the feed type
    if ($XMLReader.IsPresent) {
        $feedType = Get-PSFHFeedTypeUsingXmlReader $Url
    }
    else {
        $feedType = Get-PSFHFeedTypeUsingWebRequest $Url
    }

    # Return the feed type
    return $feedType
}

function Get-PSFHFeedTypeUsingXmlReader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        # Create an XmlReader for the URL
        $ReaderSettings = New-Object System.Xml.XmlReaderSettings
        $ReaderSettings.IgnoreComments = $true
        $ReaderSettings.IgnoreWhitespace = $true
        $ReaderSettings.DtdProcessing = 'Parse'
        $Reader = [System.Xml.XmlReader]::Create($Url, $ReaderSettings)

        # Track the presence of required elements
        $atomElements = @("feed", "title", "link", "entry")
        $rssElements = @("rss", "channel", "title", "link", "description", "item")
        $hasAtomElements = $true
        $hasRSSElements = $true

        # Read the XML until reaching the end or missing required elements
        while ($Reader.Read() -and ($hasAtomElements -or $hasRSSElements)) {
            # Check if the current node is an element
            if ($Reader.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                # Check if the element name matches Atom elements
                if ($hasAtomElements -and $Reader.Name -in $atomElements) {
                    $atomElements = $atomElements | Where-Object { $_ -ne $Reader.Name }

                    if (-not $atomElements) {
                        $hasAtomElements = $false
                        return "Atom"
                    }
                }

                # Check if the element name matches RSS elements
                if ($hasRSSElements -and $Reader.Name -in $rssElements) {
                    $rssElements = $rssElements | Where-Object { $_ -ne $Reader.Name }

                    if (-not $rssElements) {
                        $hasRSSElements = $false
                        return "RSS"
                    }
                }
            }
        }

        # Dispose the XmlReader when finished
        $xmlReader.Dispose()

        # If required elements are not found, return "Unknown"
        return "Unknown"
    }
    catch {
        # Handle errors
        Write-Error "Failed to retrieve feed type for '$Url': $($_.Exception.Message)"
        return "Unknown"
    }
}

function Get-PSFHFeedTypeUsingWebRequest {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        # Create a web request to the specified URL
        $webRequest = [System.Net.WebRequest]::Create($Url)
        $response = $webRequest.GetResponse()
        $contentType = $response.ContentType
        $stream = $response.GetResponseStream()

        # Read the response stream using a StreamReader
        $streamReader = [System.IO.StreamReader]::new($stream)
        $rssContent = $streamReader.ReadToEnd()

        # Close the StreamReader and response
        $streamReader.Close()
        $response.Close()

        # Determine the feed type based on the content type or RSS elements
        if ($contentType -match 'atom') {
            return "Atom"
        }
        elseif ($contentType -match 'rss' -or ([xml]$rssContent).rss -or ([xml]$rssContent).rss.content -match 'rss') {
            return "RSS"
        }
        else {
            return "Unknown"
        }
    }
    catch {
        # Handle errors
        Write-Error "Failed to retrieve feed type for '$Url': $($_.Exception.Message)"
        return "Unknown"
    }
}

function Get-PSFHFeedVersion {
    <#
    .SYNOPSIS
    Retrieves the version of an RSS or Atom feed from a specified URL.

    .DESCRIPTION
    This function loads the XML document from the specified URL and examines the document's structure and namespaces to determine the feed version.

    .PARAMETER Url
    Specifies the URL of the feed.

    .PARAMETER FeedType
    Specifies the type of the feed (RSS or Atom).

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Get-PSFHFeedVersion -Url "https://example.com/feed" -FeedType "RSS"
    Retrieves and returns the version of the RSS feed from the specified URL.

    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$FeedType
    )

    try {
        # Create an XML document and load the feed from the URL
        #$xmlDocument = New-Object System.Xml.XmlDocument
        #$xmlDocument.Load($Url)
        [System.Xml.XmlDocument]$xmlDocument = Import-PSFHXmlDocument -Url $Url -TimeoutInSeconds 10

        
        # Create a namespace manager for the XML document
        $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xmlDocument.NameTable)
        $namespaceManager.AddNamespace("rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
        $namespaceManager.AddNamespace("atom", "http://www.w3.org/2005/Atom")

        if ($FeedType -eq "RSS") {
            write-verbose $feedType

            # Check for RSS version 2.0
            if ($xmlDocument.SelectSingleNode('//rss/@version', $namespaceManager)."#text" -eq "2.0") {
                write-verbose "2.0"

                return "2.0"
            }
            # Check for RSS version 1.0
            elseif ($null -ne $xmlDocument.SelectSingleNode('//rdf:RDF', $namespaceManager)) {
                write-verbose "1.0"

                return "1.0"
            }
        }
        elseif ($FeedType -eq "Atom") {

            $rootNode = $xmlDocument.DocumentElement
            
            # Check for Atom version 1.0
            if ($null -ne $rootNode.SelectSingleNode('//atom:feed[@xmlns="http://www.w3.org/2005/Atom"]', $namespaceManager)) {
                return "1.0"
            }
            # Check for Atom version 1.0
            elseif ($rootNode.NamespaceURI -contains "http://www.w3.org/2005/Atom") {
                return "1.0"
            }
            
            # Check for Atom version 0.3
            elseif ($null -ne $rootNode.SelectSingleNode('//atom:feed[starts-with(@xmlns,"http://purl.org/atom/")]', $namespaceManager)) {
                return "0.3"
            }
        }

        return "Unknown"
    }
    catch {
        # Handle errors
        Write-Information "Failed to retrieve feed version for '$Url': $($_.Exception.Message)" -InformationAction Continue
        break
    }
}

function Import-PSFHXmlDocument {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [int]$TimeoutInSeconds,
        [Parameter(Mandatory = $false)]
        [ValidateSet("WebRequestClass", "InvokeWebRequest")]
        [string]$RequestType = "InvokeWebRequest"
    )

    try {

        if ($RequestType -eq "WebRequestClass") {
            # Create a web request to the specified URL
            $webRequest = [System.Net.WebRequest]::Create($Url)
            $webRequest.Timeout = $TimeoutInSeconds * 1000  # Convert timeout to milliseconds

            # Get the response from the web request
            $response = $webRequest.GetResponse()

            # Create an XML document
            $xmlDocument = New-Object System.Xml.XmlDocument

            # Load the XML document from the response stream
            $xmlDocument.Load($response.GetResponseStream())

            # Close the response
            $response.Close()

            # Validate XML structure
            if (!$xmlDocument.DocumentElement) {
                throw "Invalid XML structure in the RSS feed."
            }


            return $xmlDocument

        }
        elseif ($RequestType -eq "InvokeWebRequest") {
            $feed = [xml](Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutInSeconds).Content

            return $feed
        }
    }
    catch {
        
        Write-Information "Failed to load XML document from '$Url': $($_.Exception.Message)" -InformationAction Continue
        
        continue
    }
}

function Test-PSFHUrlAccessibility {
    <#
    .SYNOPSIS
    Tests the accessibility of a URL by sending a web request.

    .DESCRIPTION
    This function sends a web request to the specified URL to check its accessibility. If the request is successful and a response is received, it returns $true. Otherwise, it returns $false.

    .PARAMETER Url
    Specifies the URL to test for accessibility.

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Test-PSFHUrlAccessibility -Url "https://example.com"
    Tests the accessibility of the specified URL and returns $true if accessible, otherwise returns $false.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [int]$timeout = 5
    )

    Write-Verbose "Timeout: ${timeout}"

    try {
        # Create a web request to the specified URL
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Timeout = $timeout * 1000  # Timeout value in milliseconds (e.g., 5 seconds)
        # Send the request and get the response
        $response = $request.GetResponse()

        # Close the response
        $response.Close()

        # Return $true to indicate accessibility
        return $true
    }
    catch {
        # Return $false to indicate inaccessibility
        return $false
    }
}

function Get-PSFHFeed {
    <#
    .SYNOPSIS
    Retrieves an feed from a specified URL.

    .DESCRIPTION
    This function uses Invoke-WebRequest cmdlet to fetch an feed from the specified URL. It expects the response content type to be 'application/xml'.

    .PARAMETER Url
    Specifies the URL of the feed.

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Get-PSFHFeed -Url "https://example.com/rss"
    Retrieves and returns the feed from the specified URL.

    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        # Fetch the feed using Invoke-WebRequest
        $Feed = Invoke-WebRequest -Uri $Url -ContentType 'application/xml'

        # Return the feed object
        return $Feed
    }
    catch {
        # Handle errors and display a message
        Write-Information "Failed to fetch the feed. Please check the URL and try again." -InformationAction Continue

        # Return $null to indicate failure
        return $null
    }
}

function Remove-PSFHDuplicateLines {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputFile,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )
    
    try {
        # Read the contents of the input file
        $lines = [System.IO.File]::ReadAllLines($InputFile)

        # Remove empty lines and whitespace from the lines
        $lines = $lines -replace '\s+', '' | Where-Object { $_ }

        # Sort the unique lines
        $sortedLines = $lines | Sort-Object -Unique

        # Write the sorted unique lines to the output file
        [System.IO.File]::WriteAllLines($OutputFile, $sortedLines)
    }
    catch {
        Write-Warning "Failed to deduplicate, sort data: $($_.Exception.Message)"
    }
}

function Remove-PSFHDuplicateCSVRows {
    <#
    .SYNOPSIS
    Removes duplicate rows from a CSV file based on a specific column.

    .DESCRIPTION
    This function imports a CSV file, groups the data by a specified column (e.g., "Feed URL"), and creates a new collection containing only the first occurrence of each unique value in that column. The resulting unique data is then exported to a new CSV file.

    .PARAMETER InputPath
    Specifies the path to the input CSV file.

    .PARAMETER OutputPath
    Specifies the path to the output CSV file containing the unique rows.

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Remove-PSFHDuplicateCSVRows -InputPath "C:\data.csv" -OutputPath "C:\unique_data.csv"
    Removes duplicate rows based on the "Feed URL" column from the input CSV file and exports the unique data to the output CSV file.

    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    # Import the CSV file
    $data = Import-Csv -Path $InputPath

    # Group the data by the specified column
    $groupedData = $data | Group-Object -Property "Feed URL"

    # Create a new collection for unique rows
    $uniqueData = @()

    # Iterate over the grouped data and add the first occurrence of each value to the unique collection
    foreach ($group in $groupedData) {
        $uniqueData += $group.Group[0]
    }

    # Export the unique data to a new CSV file
    $uniqueData | Export-Csv -Path $OutputPath -NoTypeInformation
}

function Test-PSFHUrlFormat {
    <#
    .SYNOPSIS
    Validates the format of a URL using regular expressions.

    .DESCRIPTION
    This function performs URL format validation using regular expressions. It checks if the provided URL matches the expected format: starting with "http://" or "https://", followed by a domain name, optional port number, and optional path.

    .PARAMETER Url
    Specifies the URL to validate.

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Test-PSFHUrlFormat -Url "https://example.com"
    Validates the format of the specified URL and returns $true if the format is valid, otherwise returns $false.

    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    # Perform URL format validation using regular expressions
    #$urlRegex = '^https?://([A-Za-z0-9]+\.[A-Za-z]{2,}|localhost)(:[0-9]+)?([/?].*)?$'
    #$urlRegex = '^https?://([A-Za-z0-9]+\.[A-Za-z0-9]{1,}|localhost)(:[0-9]+)?([/?].*)?$'
    $urlRegex = '^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/.*)?$'

    if ($Url -match $urlRegex -and ([System.Uri]::IsWellFormedUriString($Url, [System.UriKind]::Absolute))) {
        return $true
    }
    else {
        return $false
    }
}

function Test-PSFHRssFeedValidity {
    <#
    .SYNOPSIS
    Checks the validity of an RSS or Atom feed.

    .DESCRIPTION
    This function checks the validity of an RSS or Atom feed by retrieving the feed content from the specified URL, analyzing its format, and counting the number of news items within a specified number of days.

    .PARAMETER FeedUrl
    Specifies the URL of the RSS or Atom feed to validate.

    .PARAMETER DaysToCount
    Specifies the number of days to consider when counting the news items in the feed. Default value is 7.

    .NOTES
    Author: Your Name
    Date: Insert Date

    .EXAMPLE
    PS> Test-PSFHRssFeedValidity -FeedUrl "https://example.com/feed" -DaysToCount 14
    Checks the validity of the specified RSS or Atom feed, considering news items published within the last 14 days. Returns $true if the feed is valid and contains news items, otherwise returns $false.

    #>
    param (
        [Parameter(ParameterSetName = 'FeedUrl', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FeedUrl,

        [Parameter(ParameterSetName = 'FeedUrl', Mandatory = $false)]
        [int]$DaysToCount = 7,

        [Parameter(ParameterSetName = 'SaveFeedData')]
        [Parameter(ParameterSetName = 'FeedUrl')]
        [switch]$SaveFeedData,

        [Parameter(ParameterSetName = 'SaveFeedData', Mandatory = $true)]
        [Parameter(ParameterSetName = 'FeedUrl')]
        [ValidateNotNullOrEmpty()]
        [string]$OutPath

    )

    try {
        # Validate and sanitize the input URL
        $validatedUrl = [System.Uri]::EscapeUriString($FeedUrl)

        $feed = [xml](Invoke-WebRequest -Uri $validatedUrl).Content

        $feedType = Get-PSFHFeedType -Url $validatedUrl -XMLReader

        if ($feedType -eq "RSS") {
            $version = Get-PSFHFeedVersion -Url $validatedUrl -FeedType "RSS"
            $newsCount = ($feed.SelectNodes('//item') | Where-Object { [datetime]$_.pubDate -ge (Get-Date).AddDays(-$DaysToCount) }).Count
        }
        elseif ($feedType -eq "Atom") {
            $version = Get-PSFHFeedVersion -Url $validatedUrl -feedType "Atom"

            try {
                # https://www.rfc-editor.org/rfc/rfc4287.html#section-4.2.9
                $newsCount = ($feed.feed.entry | Where-Object { [DateTime]$_.published -gt (Get-Date).AddDays(-$DaysToCount) }).Count
    
            }
            catch {
                if ($null -eq $newsCount -or $newsCount -eq 0) {

                    # https://www.rfc-editor.org/rfc/rfc4287.html#section-4.2.15
                    $newsCount = ($feed.feed.entry | Where-Object { [DateTime]$_.updated -gt (Get-Date).AddDays(-$DaysToCount) }).Count

                }
            }
        }
        else {
            Write-information 'Invalid feed format: The feed does not conform to the expected RSS or Atom format.' -InformationAction Continue

            break
        }

        Write-Verbose "newsCount: ${newsCount}" 


        if ($newsCount -gt 0) {

            $isoDateTime = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
            Write-Verbose "ISO 8601 format with time: $isoDateTime"
            
            # Save feed information to CSV
            $csvData = [PSCustomObject]@{
                'Feed URL'           = $validatedUrl
                'Type'               = $feedType
                'Version'            = $version
                'Days to count news' = $DaysToCount
                'News Count'         = $newsCount
                'Date check'         = $isoDateTime
            }

            if ($SaveFeedData.IsPresent) {
                Write-Verbose "save data" 
                $csvData | Export-Csv -Path $OutPath -Append -NoTypeInformation -Encoding UTF8
            }
            else {
                Write-Verbose "display data" 
                Write-information ($csvData | out-string) -InformationAction Continue
            }

            return $true 
        }
        else {
            return $false
        }
    }
    catch {
        Write-Error "Error occurred while checking the feed validity: $_"
        return $false
    }
}

function Export-PSFHFeedCSV {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        $FeedData,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$OutPath
    )

    try {
        $FeedData | Export-Csv -Path $OutPath -Append -NoTypeInformation -Encoding UTF8
    
        return $true
    }
    catch {

        return $false

    }
    
}

# Function to analyze the feed and count the number of new items published in the last specified number of days
function Invoke-PSFHFeedAnalysis {
    <#
    .SYNOPSIS
    Counts the number of new items in a given feed within a specified number of days.

    .DESCRIPTION
    The Invoke-PSFHFeedAnalysis function takes a feed (Atom or RSS) and counts the number of new items published or updated within a specified number of days.

    .PARAMETER Feed
    The feed object to analyze. It can be an Atom feed or an RSS feed.

    .PARAMETER LastDaysElements
    The number of days to consider for counting new items.

    .EXAMPLE
    $rssFeed = Get-RssFeed -Url "http://example.com/rss-feed"
    Invoke-PSFHFeedAnalysis -Feed $rssFeed -LastDaysElements 7

    This example retrieves an RSS feed from "http://example.com/rss-feed" and counts the number of new items within the last 7 days.

    .EXAMPLE
    $atomFeed = Get-AtomFeed -Url "http://example.com/atom-feed"
    Invoke-PSFHFeedAnalysis -Feed $atomFeed -LastDaysElements 30

    This example retrieves an Atom feed from "http://example.com/atom-feed" and counts the number of new items within the last 30 days.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Commands.HtmlWebResponseObject]$Feed,

        [Parameter(Mandatory = $false)]
        [switch]$LastPublishedDate,

        [Parameter(Mandatory = $false)]
        $LastDaysElements = 0
    )

    if ($LastPublishedDate.IsPresent) {
        Write-Verbose "Invoke-PSFHFeedAnalysis feed.rss.channel: $(([xml]$feed).rss.channel | out-string) "
    
    }
    $currentDate = Get-Date
    $newItemCount = 0

    if ($LastDaysElements -gt 0) {
        # Check if the feed is Atom or RSS format
        if ($Feed.rss) {
            $_lastpublisheddate = ""
            if ($LastPublishedDate.IsPresent) {
                Write-Verbose $Feed.rss
                $_lastpublisheddate = ([xml]($Feed)).rss.channel.lastbuilddate
                return $_lastpublisheddate
            }
            # Iterate over each item in the RSS feed
            foreach ($item in $Feed.rss.channel.item) {
                $itemDate = Get-Date $item.pubDate
   
                # Calculate the number of days between the current date and the item's publication date
                $daysDifference = ($currentDate - $itemDate).TotalDays
   
                # Check if the item was published within the specified number of days
                if ($daysDifference -le $LastDaysElements) {
                    $newItemCount++
                }
            }
        }
        elseif ($Feed.feed) {
            # Iterate over each entry in the Atom feed
            foreach ($entry in $Feed.feed.entry) {
                $entryDate = Get-Date $entry.updated
   
                # Calculate the number of days between the current date and the entry's updated date
                $daysDifference = ($currentDate - $entryDate).TotalDays
   
                # Check if the entry was updated within the specified number of days
                if ($daysDifference -le $LastDaysElements) {
                    $newItemCount++
                }
            }
        }
   
        # Display the number of new items found within the specified number of days
        Write-verbose "Number of new items in the last ${LastDaysElements} days: ${newItemCount}"

        return $newItemCount
    
    }
    else {
        # Check if the feed is Atom or RSS format
        try {
    
            # Convert the HTML response content to an XmlDocument
            $xmlDocument = New-Object System.Xml.XmlDocument
            $xmlDocument.LoadXml($Feed.Content)

            # Get the item elements in the XmlDocument
            $rssitems = $xmlDocument.SelectNodes("//item")
            #$atomitems = $xmlDocument.SelectNodes("//entry")
            $atomitems = $xmlDocument.feed.entry

            
            # Count the number of items
            $RSSitemCount = $rssitems.Count
            $ATOMitemCount = $atomitems.Count

            if ($RSSitemCount -gt 0) {
                # Return the item count
                $newItemCount = $RSSitemCount        

                if ($LastPublishedDate.IsPresent) {
                    if (([xml]$Feed).rss.channel.lastBuildDate) {
                        Write-Verbose "Invoke-PSFHFeedAnalysis LastPublishedDate: $(([xml]$Feed).rss.channel.lastBuildDate)"
                        $_lastpublisheddate = ([xml]$Feed).rss.channel.lastBuildDate
                        return $_lastpublisheddate
                    }
                    if ((([xml]$Feed).rss.channel.item | Select-Object -First 1).pubdate) {
                        Write-Verbose "Invoke-PSFHFeedAnalysis LastPublishedDate: $((([xml]$Feed).rss.channel.item | Select-Object -First 1).pubdate)"
                        $_lastpublisheddate = (([xml]$Feed).rss.channel.item | select-object -first 1).pubdate  
                        return $_lastpublisheddate
                    }
                    Write-Verbose "Invoke-PSFHFeedAnalysis LastPublishedDate: $(([xml]$Feed).rss.channel.pubdate)"
                    $_lastpublisheddate = ([xml]$Feed).rss.channel.pubdate
                    return $_lastpublisheddate
                }
    

            }
            elseif ($ATOMitemCount -gt 0) {
                $newItemCount = $ATOMitemCount        
                if ($LastPublishedDate.IsPresent) {
                    return ([xml]$feed).feed.updated
                }
            }
            else {
                $newItemCount = 0
            }
        }
        catch {
            Write-Output "An error occurred while processing the feed: $($_.Exception.Message)"
            return -1  # Return -1 to indicate an error occurred
        }
    
        # Iterate over each entry in the Atom feed
   
        # Display the number of new items found within the specified number of days
        return $newItemCount
    }  
}

# The purpose of this function is to retrieve and display news items from an RSS feed.
function Get-PSFHFeedNews {
    <#
    .SYNOPSIS
    Retrieves and displays news items from an RSS feed.

    .DESCRIPTION
    The Get-PSFHFeedNews function retrieves and displays news items from an RSS feed. It can retrieve the RSS feed from a URL or use an existing XML object. The function returns an array of custom objects containing the title, published date, and link of the news items.

    .PARAMETER RSSUrl
    The URL of the RSS feed to retrieve and display news items from.

    .PARAMETER Feed
    An existing XML object representing the RSS feed to retrieve and display news items from.

    .PARAMETER LastItems
    The number of latest news items to retrieve and display. Defaults to 10 if not specified.

    .EXAMPLE
    Get-PSFHFeedNews -RSSUrl 'https://www.example.com/rss' -LastItems 5

    This command retrieves and displays the 5 latest news items from the RSS feed located at the specified URL.

    .EXAMPLE
    $xml = [xml](Get-Content 'feed.xml')
    Get-PSFHFeedNews -Feed $xml

    This command retrieves and displays the latest news items from an existing XML object representing an RSS feed.

    .NOTES
    Version: 2.0
    Author: Wojciech Napierała
    #>
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'Url', Mandatory = $true, Position = 0, HelpMessage = 'The URL of the RSS feed.')]
        [ValidatePattern('^https?://.*')]
        [ValidateNotNullOrEmpty()]
        [string]$RSSUrl,

        [Parameter(ParameterSetName = 'Feed', Mandatory = $true, Position = 0, HelpMessage = 'The RSS feed as an XML object.')]
        [ValidateNotNullOrEmpty()]
        [xml]$Feed,

        [Parameter(Mandatory = $false, HelpMessage = 'The number of news items to display. Default is 10.')]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(1, 100)]
        [int]$LastItems = 10
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'Url') {
            # Validate URL
            if (![System.Uri]::IsWellFormedUriString($RSSUrl, [System.UriKind]::Absolute)) {
                throw "Invalid URL format: $RSSUrl"
            }

            # Create web request
            $webRequest = [System.Net.WebRequest]::Create($RSSUrl)
            $webRequest.Timeout = 10000  # Timeout set to 10 seconds

            # Get web response
            $webResponse = $webRequest.GetResponse()
            $stream = $webResponse.GetResponseStream()

            # Create XML reader
            $xmlReaderSettings = New-Object System.Xml.XmlReaderSettings
            $xmlReaderSettings.DtdProcessing = 'Ignore'
            $xmlReader = [System.Xml.XmlReader]::Create($stream, $xmlReaderSettings)

            # Read XML document
            $rssFeed = New-Object System.Xml.XmlDocument
            $rssFeed.Load($xmlReader)

            # Close resources
            $xmlReader.Close()
            $stream.Close()
            $webResponse.Close()
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Feed') {
            $rssFeed = $Feed
        }

        # Validate XML structure
        if (!$rssFeed.DocumentElement) {
            throw "Invalid XML structure in the RSS feed."
        }

        # Get news items
        $newsItems = $rssFeed.SelectNodes("//item")

        if ($newsItems.Count -gt 0) {
            # Create list of news items
            $newsList = foreach ($item in $newsItems | Select-Object -Last $LastItems) {
                $title = $item.SelectSingleNode("title").InnerText
                $pubDate = $item.SelectSingleNode("pubDate").InnerText
                $link = $item.SelectSingleNode("link").InnerText

                # Sanitize inputs
                $sanitizedTitle = $title.Replace("`n", "").Replace("`r", "")
                $sanitizedPubDate = $pubDate.Replace("`n", "").Replace("`r", "")
                $sanitizedLink = $link.Replace("`n", "").Replace("`r", "")

                # Create custom object
                [PSCustomObject]@{
                    Title         = $sanitizedTitle
                    PublishedDate = [datetime]$sanitizedPubDate
                    Link          = $sanitizedLink
                }
            }

            # Sort news items by published date
            $sortedNews = $newsList | Sort-Object -Property PublishedDate -Descending

            return $sortedNews
        }
        else {
            Write-Warning "No news items found in the RSS feed."
            return
        }
    }
    catch {
        Write-Error "Failed to retrieve and display news from the RSS feed: $($_.Exception.Message)"
    }
}

function Get-PSFHFeedDataFromFile {
    <#
    .SYNOPSIS
    Retrieves feed data from a file.
    
    .DESCRIPTION
    This function reads the contents of a file containing feed data and returns an XML object.
    
    .PARAMETER FeedFileFullName
    The full name of the file containing the feed data.
    
    .PARAMETER FeedType
    The type of feed data contained in the file (e.g. RSS, Atom).
    
    .EXAMPLE
    Get-PSFHFeedDataFromFile -FeedFileFullName "C:\feeds\myfeed.xml" -FeedType "RSS"
    
    This example retrieves the contents of the file "myfeed.xml" located in the "C:\feeds" directory and returns an XML object representing an RSS feed.
    
    .OUTPUTS
    System.Xml.XmlDocument
    
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FeedFileFullName,
    
        [Parameter(Mandatory = $false)]
        [ValidateSet("RSS", "Atom")]
        [string]$FeedType = "RSS"
    )
    
    try {
        Write-Verbose "Get-PSFHFeedDataFromFile FeedFileFullName: '${FeedFileFullName}'"
    
        if (-not (Test-Path $FeedFileFullName)) {
            throw "File not found: $FeedFileFullName"
        }
    
        <#
            $xmlSettings = New-Object System.Xml.XmlReaderSettings
            $xmlSettings.Schemas.Add($null, "$FeedType.xsd")
            $xmlSettings.ValidationType = [System.Xml.ValidationType]::Schema
        #>

        $xmlReader = [System.Xml.XmlReader]::Create($FeedFileFullName, $xmlSettings)
        $feedContent = New-Object System.Xml.XmlDocument
        $feedContent.Load($xmlReader)
    
        return $feedContent
    
    }
    catch {
        Write-Warning "Failed to get content of saved feed data: $($_.Exception.Message)"
    
        return $false
    }
}

# Downloads a feed from a given URL and saves it to a file.
function Save-PSFHFeed {
    <#
    .SYNOPSIS
    Downloads a feed from a given URL and saves it to a file.

    .DESCRIPTION
    The Save-PSFHFeed function downloads a feed from a given URL and saves it to a file. The function takes a mandatory URL parameter, an optional output file path parameter, and an optional timeout parameter. If the output file path is not specified, the function creates a temporary folder and saves the feed to a file with a unique name in that folder. If the function fails to save the feed data to a file, it returns false and displays a warning message.

    .PARAMETER Url
    The URL of the feed to download.

    .PARAMETER outputFilePath
    The path of the file to save the feed to. If not specified, a temporary folder is created and the feed is saved to a file with a unique name in that folder.

    .PARAMETER Timeout
    The timeout value in seconds for the web request. Default is 5 seconds.

    .EXAMPLE
    Save-PSFHFeed -Url "https://example.com/feed.xml" -outputFilePath "C:\feeds\example.xml"

    Downloads the feed from https://example.com/feed.xml and saves it to C:\feeds\example.xml.

    .NOTES
    Author: PowerShell Team
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^https?://.*')]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
                if ($_ -ne $null) {
                    $isValid = $true
                    try {
                        [System.IO.Path]::GetFullPath($_) | Out-Null
                    }
                    catch {
                        $isValid = $false
                    }
                    if (-not $isValid) {
                        throw "Invalid file path: $_"
                    }
                }
                $true
            })]
        [string]$outputFilePath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [int]$Timeout = 5
    )

    Write-Verbose "Downloading feed from '$Url'..."

    $uri = [System.Uri]$Url

    $uri = $uri.host + $uri.PathAndQuery

    # Remove any leading "www." from the domain if present
    $uri = $uri -replace '^www\.', ''
    $uri = $uri -replace '^https?:\/\/', ''

    # Replace any invalid characters with underscores
    $validFileName = $uri -replace '[^\w\d-]', '_'

    if (-not $outputFilePath) {
        $tempFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "FeedNewsTool"
        if (-not (Test-Path -Path $tempFolder -PathType Container)) {
            try {
                New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
            }
            catch {
                Write-Warning "Failed to create temporary folder: $($_.Exception.Message)"
                return $false
            }
        }
        $outputFilePath = Join-Path -Path $tempFolder -ChildPath "$validFileName.feed.tmp"
    }

    try {
        Invoke-WebRequest -Uri $Url -TimeoutSec $Timeout -OutFile $outputFilePath | Out-Null

        if (Test-Path -Path $outputFilePath -PathType Leaf) {
            Write-Verbose "Feed downloaded and saved to '$outputFilePath'."
            return $true
        }
        else {
            Write-Warning "Failed to save feed data to file: $outputFilePath"
            return $false
        }
    }
    catch {
        Write-Warning "Failed to download feed data: $($_.Exception.Message)"
        return $false
    }
}

function Get-PSFHRandomFile {
    <#
    .SYNOPSIS
    Retrieves a random file from a specified folder path.
    
    .DESCRIPTION
    This function retrieves a random file from a specified folder path. It uses the Get-ChildItem cmdlet to retrieve all files in the folder and returns a random file if there are any.
    
    .PARAMETER FolderPath
    The path of the folder to retrieve files from.
    
    .PARAMETER Count
    The number of random files to retrieve. Default is 1.
    
    .EXAMPLE
    Get-PSFHRandomFile -FolderPath "C:\Users\JohnDoe\Documents"
    
    This example retrieves a random file from the "Documents" folder of the "JohnDoe" user.
    
    .EXAMPLE
    Get-PSFHRandomFile -FolderPath "C:\Users\JohnDoe\Documents" -Count 5
    
    This example retrieves 5 random files from the "Documents" folder of the "JohnDoe" user.
    
    .NOTES
    Author: Wojciech Napierała
    Date: 26/06/2023
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType 'Container' })]
        [string]$FolderPath,
        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Count = 1
    )
    
    try {
        $files = Get-ChildItem -Path $FolderPath -File
    }
    catch {
        Write-Error "An error occurred while retrieving files from the folder. Error message: $($_.Exception.Message)"
        return
    }
    
    if ($files.Count -eq 0) {
        Write-Warning "No files were found in the specified folder path. Please check if the path is correct and if there are files in the folder."
        return
    }
    
    $randomFiles = $files | Get-Random -Count $Count
    return $randomFiles.FullName
}

function Add-PSFHUrl {
    <#
.SYNOPSIS
    Adds a URL to a file.
.DESCRIPTION
    Adds a URL to a file.
.PARAMETER Url
    The URL to add.
.PARAMETER FilePath
    The path to the file.
.EXAMPLE
    Add-PSFHUrl -Url "https://www.google.com" -FilePath "C:\Urls.txt"
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    if (Test-Path -Path $FilePath) {
        $existingUrls = Get-PSFHUrl -FilePath $FilePath
        if ($existingUrls -contains $Url) {
            Write-Warning "URL already exists."
            return
        }
    }

    if ($PSCmdlet.ShouldProcess("$Url", "Add URL to file")) {
        Add-Content -Path $FilePath -Value $Url
        Write-Verbose "URL added successfully."
    }
}

<#
.SYNOPSIS
    Removes a URL from a file.
.DESCRIPTION
    Removes a URL from a file.
.PARAMETER Url
    The URL to remove.
.PARAMETER FilePath
    The path to the file.
.EXAMPLE
    Remove-PSFHUrl -Url "https://www.google.com" -FilePath "C:\Urls.txt"
#>
function Remove-PSFHUrl {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    if (Test-Path -Path $FilePath) {
        $existingUrls = Get-PSFHUrl -FilePath $FilePath
        if ($existingUrls -notcontains $Url) {
            Write-Warning "URL does not exist."
            return
        }
    }

    if ($PSCmdlet.ShouldProcess("$Url", "Remove URL from file")) {
        $updatedUrls = $existingUrls | Where-Object { $_ -ne $Url }
        $updatedUrls | Set-Content -Path $FilePath
        Write-Verbose "URL removed successfully."
    }
}

<#
.SYNOPSIS
    Gets URLs from a file.
.DESCRIPTION
    Gets URLs from a file.
.PARAMETER FilePath
    The path to the file.
.EXAMPLE
    Get-PSFHUrl -FilePath "C:\Urls.txt"
#>
function Get-PSFHUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-Warning "File does not exist."
        return
    }

    Get-Content -Path $FilePath
}

function Format-PSFHFileUrls {
    <#
.SYNOPSIS
    Sorts URLs in a file.
.DESCRIPTION
    Sorts URLs in a file.
.PARAMETER FilePath
    The path to the file.
.EXAMPLE
    Format-PSFHFileUrls -FilePath "C:\Urls.txt"
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    if (Test-Path -Path $FilePath) {
        $existingUrls = Get-PSFHUrl -FilePath $FilePath
    }

    if ($PSCmdlet.ShouldProcess("Sort URLs in file")) {
        $sortedUrls = $existingUrls | Sort-Object -Unique
        $sortedUrls | Set-Content -Path $FilePath
        Write-Verbose "URLs sorted successfully."
    }
}

<# 
## References for Sort-Urls, Get-PSFHUrl, Remove-PSFHUrl, Add-PSFHUrl

- [Approved Verbs for Windows PowerShell Commands](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.1)
- [Writing a PowerShell Function](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/writing-a-powershell-module-manifest?view=powershell-7.1)
- [PowerShell Best Practices and Style Guide](https://poshcode.gitbooks.io/powershell-practice-and-style/content/)
- [PowerShell Scripting Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/best-practices/best-practices?view=powershell-7.1)
- [PowerShell Scripting Standards](https://docs.microsoft.com/en-us/powershell/scripting/developer/scripting-guidelines?view=powershell-7.1)
- [PowerShell Scripting Conventions](https://docs.microsoft.com/en-us/powershell/scripting/developer/scripting-conventions?view=powershell-7.1)
- [PowerShell Scripting Tips and Tricks](https://docs.microsoft.com/en-us/powershell/scripting/developer/tips-and-tricks/tips-and-tricks?view=powershell-7.1)
#>

function New-PSFHTempFeedFolder {
    param (
        [string]$FolderName
    )
    try {
        $tempfolder = [System.IO.Path]::GetTempPath()
        $feednewstoolfolderFullName = Join-Path $tempfolder $FolderName
        if (-not (Test-Path -Path $feednewstoolfolderFullName)) {
            [void](New-Item -Path $feednewstoolfolderFullName -ItemType Directory)
        }
        return $feednewstoolfolderFullName
    }
    catch {
        Write-Error "An error creating '$feednewstoolfolderFullName': $_"
    }
}

function Start-PSFeedHandler {
    <#
.SYNOPSIS
    Performs various operations related to news feeds.

.DESCRIPTION
    The 'FeedNewsTool' function allows you to process and analyze news feeds from either a file or a URL. It provides functionality for validating and analyzing feeds, checking URL accessibility, and removing duplicate rows from a CSV file.

.PARAMETER validateFeedListFromFilename
    Specifies that the function should process data from a file containing a list of feed URLs.

.PARAMETER validateFeedListFilename
    Specifies the filename of the feed list file. This parameter is mandatory when 'validateFeedListFromFilename' is used.

.PARAMETER TestFeedFromUrl
    Specifies that the function should process data from a feed URL.

.PARAMETER TestFeedUrl
    Specifies the URL of the feed. This parameter is mandatory when 'TestFeedFromUrl' is used.

.PARAMETER LastDaysElements
    Specifies the number of past days' elements to analyze in the feed. This parameter is optional and only applicable when 'validateFeedFromUrl' is used.

.PARAMETER RemoveDuplicateCSVRows
    Specifies that the function should process data in a file and remove duplicate rows.

.PARAMETER InputPath
    Specifies the input file path containing the CSV data. This parameter is mandatory when 'RemoveDuplicateCSVRows' is used.

.PARAMETER OutputPath
    Specifies the output file path where the CSV data without duplicate rows will be saved. This parameter is mandatory when 'RemoveDuplicateCSVRows' is used.

.PARAMETER TestUrlFormat
    Specifies the URL to test for proper format.

.PARAMETER ShowNews
    Specifies that the function should display news from a feed URL.

.PARAMETER ShowNewsUrlFeed
    Specifies the URL of the feed to display news from. This parameter is mandatory when 'ShowNews' is used.

.PARAMETER LastNewsCount
    Specifies the number of news items to display. This parameter is optional and only applicable when 'ShowNews' is used.

.PARAMETER ShowNewsfromFeed
    Specifies that the function should display news from a saved feed.

.PARAMETER ShowNewsfromFeedfileRandom
    Specifies that the function should display news from a random saved feed.

.PARAMETER AddFeed
    Specifies that the function should add a feed to the saved feed list.

.PARAMETER FeedUrl
    Specifies the URL of the feed to add. This parameter is mandatory when 'AddFeed' is used.

.PARAMETER SavePath
    Specifies the path to save the feed data. This parameter is mandatory when 'AddFeed' is used.

.PARAMETER Timeout
    Specifies the timeout value for URL accessibility testing. This parameter is optional and only applicable when 'AddFeed' is used.

.PARAMETER SaveFeed
    Specifies that the function should save a feed to a file.

.PARAMETER SaveFeedUrl
    Specifies the URL of the feed to save. This parameter is mandatory when 'SaveFeed' is used.

.PARAMETER SaveFile
    Specifies the file path to save the feed data. This parameter is mandatory when 'SaveFeed' is used.

.PARAMETER SaveFeedTimeout
    Specifies the timeout value for saving the feed data. This parameter is optional and only applicable when 'SaveFeed' is used.

.PARAMETER GetSavedFeed
    Specifies that the function should retrieve a saved feed.

.PARAMETER GetSavedFeedFileFullName
    Specifies the file path of the saved feed to retrieve. This parameter is mandatory when 'GetSavedFeed' is used.
#>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'ValidateFeedListFromFilename', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ValidateFeedListFilename,

        [Parameter(ParameterSetName = 'ValidateFeedListFromFilename')]
        [switch]$SaveToTempFeedFolder,

        [Parameter(ParameterSetName = 'TestFeedFromUrl', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$TestFeedUrl,

        [Parameter(ParameterSetName = 'TestFeedFromUrl', Mandatory = $false)]
        [int]$LastDaysElements = 0,

        [Parameter(ParameterSetName = 'RemoveDuplicateCSVRows', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$InputPath,
        [Parameter(ParameterSetName = 'RemoveDuplicateCSVRows', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(ParameterSetName = 'TestUrlFormat', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$TestUrlFormat,

        [Parameter(ParameterSetName = 'ShowNews', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$ShowNewsUrlFeed,
        [Parameter(ParameterSetName = 'ShowNews', Mandatory = $false)]
        [Parameter(ParameterSetName = 'ShowNewsfromFeed', Mandatory = $false)]
        [int]$LastNewsCount = 10,

        [Parameter(ParameterSetName = 'ShowNewsfromFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ShowNewsfromFeed,

        [Parameter(ParameterSetName = 'ShowNewsfromFeedfileRandom', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [switch]$ShowNewsfromFeedfileRandom,

        [Parameter(ParameterSetName = 'AddFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$FeedUrl,
        [Parameter(ParameterSetName = 'AddFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SavePath,
        [Parameter(ParameterSetName = 'AddFeed', Mandatory = $false)]
        [int]$Timeout = 5,

        [Parameter(ParameterSetName = 'SaveFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$SaveFeedUrl,
        [Parameter(ParameterSetName = 'SaveFeed', Mandatory = $false)]
        [int]$SaveFeedTimeout = 5,

        [Parameter(ParameterSetName = 'GetSavedFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GetSavedFeedFileFullName
    )
    Get-PSFHBanner
    switch ($PSCmdlet.ParameterSetName) {
        'ValidateFeedListFromFilename' {
            # Process data from a file
            Write-Verbose "Processing data from file: ${ValidateFeedListFilename}"
            $newsDirectory = $PSScriptRoot

            $repositoryListPath = "${newsDirectory}\${ValidateFeedListFilename}"

            $cryptoRssRepos = Find-PSFHCryptoRssRepositories -ListPath $repositoryListPath

            foreach ($repo in $cryptoRssRepos) {
                # Prompt the user for an RSS URL
                $rssUrl = $repo

                # Validate the URL format
                if (Test-PSFHUrlFormat $rssUrl) {
                    # Fetch the RSS feed
                    [Microsoft.PowerShell.Commands.HtmlWebResponseObject]$responseFeed = Get-PSFHFeed $rssUrl
                    #$rssFeed.rss
                    if ($responseFeed) {
                        # Determine the type of feed and its version
                        #Get-FeedTypeAndVersion $responseFeed

                        $feedData = Get-PSFHFeedInfo $rssUrl

                        # Check the URL accessibility
                        #$feedData | Add-Member -TypeName noteproperty - Test-PSFHUrlAccessibility $rssUrl -timeout 2
                        $feedData | Add-Member -MemberType NoteProperty -NotePropertyName "UrlAccessibility" -NotePropertyValue (Test-PSFHUrlAccessibility $rssUrl -timeout 2)
                        #$feedData += Test-PSFHRssFeedValidity $rssUrl
                        $feedData | Add-Member -MemberType NoteProperty -NotePropertyName "RssFeedValidity" -NotePropertyValue (Test-PSFHRssFeedValidity $rssUrl)
                        # Analyze the feed
                        #$feedData += Invoke-PSFHFeedAnalysis $responseFeed
                        $feedData | Add-Member -MemberType NoteProperty -NotePropertyName "FeedAnalysis" -NotePropertyValue (Invoke-PSFHFeedAnalysis $responseFee)
                        if ($Save.IsPresent) {
                            try {
                                #Start-FeedNewsTool -SaveFeedUrl $rssUrl -SaveFeedTimeout 10
                                Save-PSFHFeed -Url $rssUrl -Timeout 10
                            }
                            catch {
                                $feedData
                                continue
                            }
                        }
                        $feedData
                    } 
                }
            }
            break
        }
        'TestFeedFromUrl' {
            # Process data from a URL
            Write-Verbose "Processing data from URL: ${TestFeedUrl}"
            if ((Test-PSFHUrlFormat -Url $TestFeedUrl) -and (Test-PSFHUrlAccessibility -Url $TestFeedUrl -Timeout 5)) {
                Write-Verbose "Test URL: OK"
                $objectfeed = Get-PSFHFeedInfo $TestFeedUrl

                $objectfeed | Format-List *
            }
            else {
                Write-Verbose "Test URL: Failed"
                break
            }

            break
        }
        'TestUrlFormat' {
            Test-PSFHUrlFormat -Url $TestUrlFormat
            break
        }
        'RemoveDuplicateCSVRows' {
            # Process data in file - remove duplicates
            Write-Verbose "Processing data from file: ${InputPath} to file: ${OutputPath}"
            Remove-PSFHDuplicateCSVRows -InputPath $InputPath -OutputPath $OutputPath
            break
        }
        'ShowNews' {
            Get-PSFHFeedNews -RSSUrl $ShowNewsUrlFeed -LastItems $LastNewsCount

            break
        }
        'ShowNewsfromFeed' {
            $feedfromfile = Get-PSFHFeedDataFromFile -FeedFileFullName $ShowNewsfromFeed
            Get-PSFHFeedNews -Feed $feedfromfile -LastItems $LastNewsCount
            break
        }
        'ShowNewsfromFeedfileRandom' {
            #$tempfolder = [System.IO.Path]::GetTempPath()
            $feednewstoolfolder = "feednewstool"
            #$feednewstoolfolderFullName = Join-Path $tempfolder $feednewstoolfolder
            $tempFeedFolder = New-PSFHTempFeedFolder -FolderName $feednewstoolfolder
            write-host "News feed folder: ""$tempFeedFolder""" -ForegroundColor DarkYellow
            $RandomFeedFileFullName = Get-PSFHRandomFile -FolderPath $tempFeedFolder -Count 1
            if ($RandomFeedFileFullName.count -gt 0) {
                $feedfromfile = Get-PSFHFeedDataFromFile -FeedFileFullName $RandomFeedFileFullName
                Get-PSFHFeedNews -Feed $feedfromfile -LastItems $LastNewsCount
            }
            break
        }
        'AddFeed' {
            Write-Verbose "Adding feed: ${FeedUrl}"
            if ((Test-PSFHUrlFormat -Url $FeedUrl) -and (Test-PSFHUrlAccessibility -Url $FeedUrl -Timeout $Timeout)) {
                $feedData = Get-PSFHFeedInfo -Url $FeedUrl

                if ($feedData) {
                    Write-Verbose "Exporting feed data to CSV"
                    Export-PSFHFeedCSV -FeedData $feedData -OutPath $SavePath
                }
            }
            break
        }
        'SaveFeed' {
            Write-Verbose "Saving feed: ${SaveFeedUrl}"
            $savefeedout = Save-PSFHFeed -Url $SaveFeedUrl -Timeout $SaveFeedTimeout
            Write-Verbose "Save feed output: ${savefeedout}"
            break
        }
        'GetSavedFeed' {
            Get-PSFHFeedDataFromFile -FeedFileFullName $GetSavedFeedFileFullName
            break
        }
        default {
            $helpinfo = @'
How to use, examples:
PSFeedHandler -TestFeedUrl "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf"
PSFeedHandler -InputPath .\News\feed_info2.csv -OutputPath .\News\feed_info3.csv
PSFeedHandler -TestUrlFormat "http://gigaom.com/feed/"
PSFeedHandler -ShowNewsUrlFeed "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -LastNewsCount 5
PSFeedHandler -ShowNewsfromFeed 'C:\Users\voytas\AppData\Local\Temp\FeedNewsTool\allafrica_com_tools_headlines_rdf_latest_headlines_rdf.feed.tmp'
PSFeedHandler -ShowNewsfromFeedfileRandom
PSFeedHandler -FeedUrl "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -SavePath .\News\test.txt -Timeout 10
PSFeedHandler -SaveFeedUrl "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -SaveFeedTimeout 10
PSFeedHandler -GetSavedFeedFileFullName 'C:\Users\voytas\AppData\Local\Temp\FeedNewsTool\allafrica_com_tools_headlines_rdf_latest_headlines_rdf.feed.tmp'
PSFeedHandler -ValidateFeedListFilename "repository_list.txt" -SaveToTempFeedFolder
    -save - save to temp feed folder
'@
            Write-Output $helpinfo
            break
        }
    }
}

# Function to display the PowerShell Awesome Framework banner
function Get-PSFHBanner {
    param (
        
    )
    
    $banner = get-content -Path "${PSScriptRoot}\images\PSFHbanner.txt"
    Write-Output $banner
    return

}



#news9 -TestFeedFromUrl -TestFeedUrl "https://www.theguardian.com/uk/rss"
#news9 -TestFeedFromUrl -TestFeedUrl "http://digiday.com/feed/"

# atom example: "https://github.com/voytas75/find-taskserviceuser/releases.atom"
# atom example: https://rsshub.app/github/repos/voytas75
# atom example: https://rsshub.app/github/trending/daily/powershell/en
# atom example: https://rsshub.app/github/topics/powershell
# atom example: https://rsshub.app/github/search/powershell/bestmatch/desc

# rss example: "http://digiday.com/feed/"


<#  

Get-FeedType : Failed to retrieve feed type for 'http://news.nationalgeographic.com/index.rss': Exception calling "Read" with "0" argument(s): "doctype' to nieoczekiwany
token. Oczekiwany token to 'DOCTYPE'. wiersz 2, pozycja 11."
At D:\dane\voytas\Dokumenty\visual_studio_code\lokalne\SkryptyVoytasa_lokalnie\News\news9.ps1:831 char:25
+             $feedType = Get-FeedType -Url $TestFeedUrl -XMLReader
+                         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Get-FeedType





    #>
#New-Alias -Name "FeedNewsTool" -Value "Start-FeedNewsTool" -Force
#FeedNewsTool 


# Save the current TLS security protocol to restore it later
#$oldProtocol = [Net.ServicePointManager]::SecurityProtocol

# Switch to using TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# Get the name of the current module
$ModuleName = "PSFeedHandler"

# Get the installed version of the module
$ModuleVersion = [version]"0.0.1"

# Find the latest version of the module in the PSGallery repository
$LatestModule = Find-Module -Name $ModuleName -Repository PSGallery

try {
    if ($ModuleVersion -lt $LatestModule.Version) {
        Write-Host "An update is available for $($ModuleName). Installed version: $($ModuleVersion). Latest version: $($LatestModule.Version)." -ForegroundColor Red
    } 
}
catch {
    Write-Error "An error occurred while checking for updates: $_"
}

Write-Host "Welcome to PSFeedHandler!" -ForegroundColor DarkYellow
Write-Host "Thank you for using PSFH ($($moduleVersion))." -ForegroundColor Yellow
#Write-Host "Some important changes and informations that may be of interest to you:" -ForegroundColor Yellow
#Write-Host "- You can filter the built-in snippets (category: 'Example') by setting 'ShowExampleSnippets' to '`$false' in config. Use: 'Save-PAFConfiguration -settingName ""ShowExampleSnippets"" -settingValue `$false'" -ForegroundColor Yellow
