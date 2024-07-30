#

<div style="position: relative; float: left; padding-bottom:15px">
    <div style="float: left;">
        <img src="https://github.com/voytas75/PSFeedHandler/blob/master/PSFeedHandler/images/PSFeedHandler100x100.png?raw=true">
    </div>
    <div style="margin-left: 110px;position: absolute; bottom: 0;">
        <H1>PSFeedHandler</H1>
    </div>
</div>
<div style="clear:both;"></div>

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6KYBUS)

[![status](https://img.shields.io/badge/PROD-v0.0.1-green)](https://github.com/voytas75/PSFeedHandler/blob/master/Module/docs/ReleaseNotes.md) &nbsp; [![PowerShell Gallery Version (including pre-releases)](https://img.shields.io/powershellgallery/v/PSFeedHandler)](https://www.powershellgallery.com/packages/PSFeedHandler) &nbsp; [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSFeedHandler)](https://www.powershellgallery.com/packages/PSFeedHandler) &nbsp; [![Codacy Badge](https://app.codacy.com/project/badge/Grade/6a39e86a110b49f3884a8f918045b2c3)](https://app.codacy.com/gh/voytas75/PSFeedHandler/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

[![status](https://img.shields.io/badge/DEV-v0.0.2-red)](https://github.com/voytas75/PSFeedHandler/blob/master/Module/docs/ReleaseNotes.md)

## Overview

The [PSFeedHandler](https://www.powershellgallery.com/packages/PSFeedHandler) module is your ultimate solution for efficient management and exploration of Atom and RSS feeds using PowerShell. Designed to streamline your feed-related tasks, this module offers an array of cmdlets that empower you to seamlessly detect feed types (RSS or Atom), determine feed versions, preview news content, assess connectivity, and effortlessly save feed data for future reference.

## Features

- **Detect Feed Type:** Quickly identify whether a feed is an Atom or RSS format, enabling customized handling based on the feed's structure.
- **Detect Feed Version:** Gain insights into the version of a feed (such as RSS 2.0 or Atom 1.0), ensuring compatibility and accurate parsing.
- **Show News:** Retrieve and display the latest news articles directly from the feed, providing you with up-to-date information.
- **Show Published Date:** View publication dates of news items, facilitating chronological analysis and trend tracking.
- **Test Connectivity:** Effortlessly validate connectivity to feed sources, ensuring uninterrupted access to vital data.
- **Save Feed Data:** Seamlessly store feed content locally, allowing for offline exploration, analysis, and archival.

Whether you're a developer, content curator, or data enthusiast, the PSFeedHandler module simplifies the complexities of feed interaction, making it an indispensable tool for a wide range of scenarios.

## Installation and Usage

The module is available on [PowerShell Gallery](https://www.powershellgallery.com/packages/PSFeedHandler).

```powershell
Install-Module -Name PSFeedHandler
```

Import module:

```powershell
Import-Module -Module PSFeedHandler
```

To get all commands in installed module including cmdlets, functions and aliases:

```powershell
Get-Command -Module PSFeedHandler
```

Start module:

```powershell
Start-PSFeedHandler
```

or

```powershell
PSFH
```

or

```powershell
PSFeedHandler
```

## Versioning

We use [SemVer](http://semver.org/) for versioning.

## Contributing

We welcome contributions from the community! Feel free to submit pull requests, report issues, or suggest new features to make the framework even more powerful and user-friendly.

**Clone the Repository:** Clone the PSFeedHandler repository to your local machine.

### License

The PSFeedHandler is released under the [MIT License](https://github.com/voytas75/PSFeedHandler/blob/master/LICENSE).

**Contact:**
If you have any questions or need assistance, please feel free to reach out to us via [GitHub Issues](https://github.com/voytas75/PSFeedHandler/issues).

Join us on the journey to make PowerShell scripting a truly awesome experience!
