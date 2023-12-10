# Setup executable locations.
$Commands = @("ffmpeg", "ffprobe", "gifski", "apngasm")

foreach ($Command in $Commands) {
    if (Test-Path ("$PSScriptRoot\$Command.exe")) {
        New-Variable -Name "$Command" -Value "./$Command.exe"
    } else {
        New-Variable -Name "$Command" -Value "$Command.exe"
    }
}

function New-VifpicsOptions
{
    $NewOptions = [PSCustomObject]@{
        InputPath = ""
        OutputPath = ""
        Format = "gif"
        Animate = $True
        Merge = $False
        MergeFormat = $null
        Frames = $False
        Start = "0:00"
        Duration = 1
        Timestamps = $null
        NoTimeLimit = $False
        NoFilter = $False
        Preset = $null
        Size = $null
        Width = -1
        Height = -1
        NoAutoScale = $False
        FPS = $null
        NoLoop = $False
        Encoder = "ffmpeg"
        Dither = "sierra2_4a"
        GifskiQuality = 100
        WebPCompression = 4
        WebPQuality = 75
        PNGCompressMethod = "-z1"
        LibSVT = $False
        LibAOM = $False
        AVIFQ = 8
        CRF = 21
        FilmGrain = 8
        Resolution = $null
        ForceOriginalAspectRatio = $null
        LoopOption = $null
    }

    Return $NewOptions
}

function Main
{
    begin {
        $HasFFmpeg = Test-Command -Command "ffmpeg"
        if (-not $HasFFmpeg) {
            Write-Host "FFmpeg must be installed or located in the same folder" -ForegroundColor DarkRed
            Write-Host "as Vifpics for Vifpics to run properly." -ForegroundColor DarkRed
            Write-Host "Website: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor Cyan
            Pause
            Clear-Host
            EXIT
        }

        # Set Vifpics global variables.
        $Version = "0.1.0"
        $TempPath = "$Env:TEMP\Vifpics"
        $SupportedAnimations = @("gif", "webp", "png", "apng", "avif") | Sort-Object
        $SupportedImages = @("gif", "webp", "png", "apng", "avif", "jpg", "jpeg") | Sort-Object
        $SupportedVideos =  @("mp4", "mkv", "webm") | Sort-Object
        $SupportedInputTypes =  @("file", "dir") | Sort-Object
        $TimeCodePattern = '^([0-5]\d)[:\.]([0-5]\d)$'
        $TimeCodePattern2 = '^([0-5]\d)[:\.]([0-5]\d)[:\.]([0-5]\d)$'
        $TimeCodePattern3 = '^(?:(\d+):)?([0-5]?\d)(?:\.(\d{1,2}))?$'

        $ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } # For sorting files by natual order.
        $ConcatFlag = "-f concat -safe 0".Split(" ")

        $OptionsData = New-VifpicsOptions

        # Get user input from interactive mode.
        Start-Interactive -OptionsData $OptionsData

        # Check and set input file data.
        $InputData = Test-Input $OptionsData.InputPath

        # If input is a folder, use merge task.
        if ($InputData.InputType -eq "dir") {
            $OptionsData.Merge = $True
            $OptionsData.Animate = $False
        }

        # Set timestams
        $TimestampsData = Set-TimeStamps -InputData $InputData -OptionsData $OptionsData
        
        # Apply encoder preset.
        Set-EncoderPreset -OptionsData $OptionsData
        
        # Apply size preset.
        Set-SizePreset -OptionsData $OptionsData

        # Apply animation options.
        Set-AnimationOptions -OptionsData $OptionsData        
    }

    process {
        if ($OptionsData.Animate) {
            New-Animation -InputData $InputData -OptionsData $OptionsData -TimestampsData $TimestampsData
        } elseif ($OptionsData.Merge) {
            New-Merge -InputData $InputData -OptionsData $OptionsData -TimestampsData $TimestampsData
        }  elseif ($OptionsData.Frames) {
            New-Frames -InputData $InputData -OptionsData $OptionsData -TimestampsData $TimestampsData
        } else {
            Show-ErrorMessage "Invalid task."
        }
    }

    end {
        Write-Host "Done." -ForegroundColor Cyan
        Pause
        Main
    }
}

<#
    INTERACTIVE MENU
    ________________________________________________________________________________
#>
function Show-MenuHeader
{
    [console]::CursorVisible = $False

    Write-Host "Vifpics Video To Animation by DeAndre Queary" -ForegroundColor Green
    Write-Host "Current Location: $PWD"
    Write-Host "UP - go up / DOWN - go down / ENTER - select / enter [\]/ESC - go home"
    Write-Host "-----------------------------------------------------------------------------------"
}

function Start-Interactive
{
    param (
        [int32] $CurrentSelection = 0,
        [object] $OptionsData
    )

    Clear-Host
    Show-MenuHeader

    $Key = 0

    Write-Host "CHOOSE A TASK:" -ForegroundColor Magenta
    $Options = 0..4
    $Options[0] = "📹 Create Animation"
    $Options[1] = "✂️ Generate Frames"
    $Options[2] = "▶️ Show Formats"
    $Options[3] = "❔ About"
    $Options[4] = "🚪 LEAVE!"
    Draw-MenuOptions -Options $Options -POS $CurrentSelection

    while ($Key -ne 13 -and $Key -ne 27) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode

        if ($Key -eq 13 -and $CurrentSelection -eq 0) 
        {
            Start-CreateAnimation -OptionsData $OptionsData
        }

        if ($Key -eq 13 -and $CurrentSelection -eq 1) 
        {
            Start-CreateFrames -OptionsData $OptionsData
        }

        if ($Key -eq 13 -and $CurrentSelection -eq 2) 
        {
            Show-Formats
        }

        if ($Key -eq 13 -and $CurrentSelection -eq 3) 
        {
            Show-About
        }

        if ($Key -eq 13 -and $CurrentSelection -eq 4) 
        {
            $Exit = $True
        }

        $Key, $Options, $CurrentSelection = Get-UpDownControls -Key $Key -Options $Options -CurrentSelection $CurrentSelection

        # ESC KEY
        if ($Key -eq 27 -or $Key -eq 220 -or ($Key -eq 13 -and $Exit)) 
        {
            Write-Host "Goodbye.🙋🏾‍♂️" -ForegroundColor Green
            Start-Sleep 0.5
            Clear-Host
            EXIT
        }
    }
}

function Start-CreateAnimation
{
    param (
        [int32] $CurrentSelection = 0,
        [object] $OptionsData
    )

    Clear-Host
    Show-MenuHeader

    $Key = 0

    [console]::CursorVisible = $True

    Write-Host "CREATE ANIMATION:" -ForegroundColor Magenta
    Write-Host "Enter video, image, or folder path." -ForegroundColor Cyan
    do {
        $InputPath = Read-Host "[Enter path]"
        Cancel-Read -Option $InputPath
    } while ($InputPath -eq "")

    $InputPath = Trim-String -String $InputPath
    $InputPath = $InputPath.Split(",")
    $InputPath = $InputPath.Trim()

    $InteractiveInput = Test-Input $InputPath

    if (($InteractiveInput.InputType -eq "file" -or $InteractiveInput.InputType -eq "dir") -and -not (Test-Path "$InputPath")) {
        Write-Host -Message "File path `"$InputPath`" doesn't exist. Try again." -ForegroundColor DarkRed
        Pause
        Start-CreateAnimation -OptionsData $OptionsData
        Return
    }

    if (-not (Test-Path "$InputPath") -or $InteractiveInput.InputType -eq "array") {
        Show-ErrorMessage -Message "Video path `"$InputPath`" doesn't exist. Try again." Start-CreateAnimation -OptionsData $OptionsData
    }
    Write-Host "SOURCE:"`"$InputPath`" -ForegroundColor Yellow

    Write-Host "-----------------------------------"

    [console]::CursorVisible = $False

    Write-Host "Select animation format." -ForegroundColor Cyan

    $Options = 0..10
    $Options[0] = "Standard Animated GIF (fast encode)"
    $Options[1] = "   High Quality Animated GIF (slow encode)"
    $Options[2] = "   Best Quality Animated GIF (requires gifski)"
    $Options[3] = "Animated WebP"
    $Options[4] = "Animated PNG"
    $Options[5] = "   Optimized Animated PNG (requires apngasm)"
    $Options[6] = "Animated AVIF (fast encode)"
    $Options[7] = "   Best Quality Animated AVIF (slow encode)"
    $Options[8] = "MP4 Video"
    $Options[9] = "MKV Video"
    $Options[10] = "WebM Video"

    Draw-MenuOptions -Options $Options -POS $CurrentSelection

    while ($Key -ne 13 -and $Key -ne 27) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode

        if ($Key -eq 13 -and $CurrentSelection -eq 0) {$Preset = "standard"}
        if ($Key -eq 13 -and $CurrentSelection -eq 1) {$Preset = "hq"}
        if ($Key -eq 13 -and $CurrentSelection -eq 2) {$Preset = "best"}
        if ($Key -eq 13 -and $CurrentSelection -eq 3) {$Preset = "webp"}
        if ($Key -eq 13 -and $CurrentSelection -eq 4) {$Preset = "png"}
        if ($Key -eq 13 -and $CurrentSelection -eq 5) {$Preset = "pngopt"}
        if ($Key -eq 13 -and $CurrentSelection -eq 6) {$Preset = "avif"}
        if ($Key -eq 13 -and $CurrentSelection -eq 7) {$Preset = "hq-avif"}
        if ($Key -eq 13 -and $CurrentSelection -eq 8) {$Preset = "mp4"}
        if ($Key -eq 13 -and $CurrentSelection -eq 9) {$Preset = "mkv"}
        if ($Key -eq 13 -and $CurrentSelection -eq 10) {$Preset = "webm"}

        $Key, $Options, $CurrentSelection = Get-UpDownControls -Key $Key -Options $Options -CurrentSelection $CurrentSelection

        # ESC KEY
        Invoke-InteractiveEsc
    }

    if (($Preset -eq "best") -and -not (Test-Command "gifski")) {
        Write-Host "Gifski must be installed in order to create higher quality GIFs." -ForegroundColor DarkRed
        Write-Host "Website: https://github.com/ImageOptim/gifski" -ForegroundColor Cyan
        Pause
		Start-CreateAnimation -OptionsData $OptionsData
        Return
    }
	
    if ($Preset -eq "pngopt" -and -not (Test-Command "apngasm")) {
        Write-Host "apngasm must be installed in order to create optimized PNGs." -ForegroundColor DarkRed
        Write-Host "Website: https://apngasm.sourceforge.net" -ForegroundColor Cyan
        Pause
		Start-CreateAnimation -OptionsData $OptionsData
        Return
    }

    Write-Host "ANIMATION PRESET:"$Options[$CurrentSelection] -ForegroundColor Yellow

    Write-Host "-----------------------------------"

    $Key = 0
    $CurrentSelection = 0

    Write-Host "Select size preset. Will autoscale based on height of video." -ForegroundColor Cyan

    $Options = 0..15
    $Options[0] = "Original Resolution"
    $Options[1] = "Tiny (16x16)"
    $Options[2] = "Icon (32x32)"
    $Options[3] = "Big Icon (64x64)"
    $Options[4] = "Small (128x128)"
    $Options[5] = "Twitch Emote (128x128/no autoscale)"
    $Options[6] = "Twitch Emote WIde (336x128/no autoscale)"
    $Options[7] = "Medium (256x256)"
    $Options[8] = "Large (512x512)"
    $Options[9] = "Web (640x360)"
    $Options[10] = "SD (640x480)"
    $Options[11] = "HD (1280x720)"
    $Options[12] = "Full HD (1920x1080)"
    $Options[13] = "2K (2560x1440)"
    $Options[14] = "4K (3840x2160)"
    $Options[15] = "8K (7680x4320)"

    Draw-MenuOptions -Options $Options -POS $CurrentSelection

    while ($Key -ne 13 -and $Key -ne 27) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode

        if ($Key -eq 13 -and $CurrentSelection -eq 0) {$Size = "original"}
        if ($Key -eq 13 -and $CurrentSelection -eq 1) {$Size = "tiny"}
        if ($Key -eq 13 -and $CurrentSelection -eq 2) {$Size = "icon"}
        if ($Key -eq 13 -and $CurrentSelection -eq 3) {$Size = "big-icon"}
        if ($Key -eq 13 -and $CurrentSelection -eq 4) {$Size = "small"}
        if ($Key -eq 13 -and $CurrentSelection -eq 5) {$Size = "emote"}
        if ($Key -eq 13 -and $CurrentSelection -eq 6) {$Size = "wide-emote"}
        if ($Key -eq 13 -and $CurrentSelection -eq 7) {$Size = "medium"}
        if ($Key -eq 13 -and $CurrentSelection -eq 8) {$Size = "large"}
        if ($Key -eq 13 -and $CurrentSelection -eq 9) {$Size = "web"}
        if ($Key -eq 13 -and $CurrentSelection -eq 10) {$Size = "sd"}
        if ($Key -eq 13 -and $CurrentSelection -eq 11) {$Size = "hd"}
        if ($Key -eq 13 -and $CurrentSelection -eq 12) {$Size = "fhd"}
        if ($Key -eq 13 -and $CurrentSelection -eq 13) {$Size = "2k"}
        if ($Key -eq 13 -and $CurrentSelection -eq 14) {$Size = "4k"}
        if ($Key -eq 13 -and $CurrentSelection -eq 15) {$Size = "8k"}

        $Key, $Options, $CurrentSelection = Get-UpDownControls -Key $Key -Options $Options -CurrentSelection $CurrentSelection

        # ESC KEY
        Invoke-InteractiveEsc
    }

    Write-Host "SIZE PRESET:"$Size -ForegroundColor Yellow

    Write-Host "-----------------------------------"

    [console]::CursorVisible = $False

    $Key = 0
    $CurrentSelection = 0

    Write-Host "Set FPS." -ForegroundColor Cyan

    $Options = 0..9
    $Options[0] = "30fps"
    $Options[1] = "60fps"
    $Options[2] = "50fps"
    $Options[3] = "40fps"
    $Options[4] = "25fps"
    $Options[5] = "20fps"
    $Options[6] = "15fps"
    $Options[7] = "10fps"
    $Options[8] = "5fps"
    $Options[9] = "2fps"

    Draw-MenuOptions -Options $Options -POS $CurrentSelection

    while ($Key -ne 13 -and $Key -ne 27) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode

        $FPS = $Options[$CurrentSelection]

        $Key, $Options, $CurrentSelection = Get-UpDownControls -Key $Key -Options $Options -CurrentSelection $CurrentSelection

        # ESC KEY
        Invoke-InteractiveEsc
    }

    Write-Host "FPS:"$FPS -ForegroundColor Yellow
    
    $FPS = $FPS -replace "[a-zA-Z]", ""

    Write-Host "-----------------------------------"

    if ($InteractiveInput.InputType -ne "dir" -and -not ($InteractiveInput.InputFormat -in ($SupportedImages))) {
       
        $Start = Start-GetStartTimecode

        Write-Host "START AT:"$Start -ForegroundColor Yellow

        Write-Host "-----------------------------------"

        $Duration = Start-GetEndTimeCode

        if ($Duration -lt 1 -and (Test-Integer $Duration)) {
            $NoTimeLimit = $True
            Write-Host "DURATION: No Time Limit." -ForegroundColor Yellow
        } else {
            Write-Host "DURATION:"$Duration -ForegroundColor Yellow
        }

        Write-Host "-----------------------------------"
    } else {
        $Start = "0:00"
        $Duration = $null
        $NoTimeLimit = $null
    }
    
    if ($Preset -ne "mp4" -and $Preset -ne "mkv" -and $Preset -ne "webm") {
        [console]::CursorVisible = $False

        $Key = 0
        $CurrentSelection = 0

        $Options = 0..1
        $Options[0] = "Yes"
        $Options[1] = "No"

        Write-Host "Loop animation?" -ForegroundColor Cyan
        Draw-MenuOptions -Options $Options -POS $CurrentSelection

        while ($Key -ne 13 -and $Key -ne 27) {
            $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode

            if ($Key -eq 13 -and $CurrentSelection -eq 0) 
            {
                $NoLoop = $False
            }

            if ($Key -eq 13 -and $CurrentSelection -eq 1) 
            {
                $NoLoop = $True
            }

            $Key, $Options, $CurrentSelection = Get-UpDownControls -Key $Key -Options $Options -CurrentSelection $CurrentSelection
            
            # ESC KEY
            Invoke-InteractiveEsc
        }

        if ($NoLoop -eq $False) {
            Write-Host "LOOP: Yes" -ForegroundColor Yellow
            $NoLoop = $False
        } else {
            Write-Host "LOOP? No" -ForegroundColor Yellow
            $NoLoop = $True
        }

        Write-Host "-----------------------------------"
    } else {
        $NoLoop = $null
    }

    [console]::CursorVisible = $True

    Write-Host "Enter output filename path without extension." -ForegroundColor Cyan
    Write-Host "If left blank, a filename will be generated." -ForegroundColor Cyan

    $OutputPath = Read-Host "[Enter output path]"
    Cancel-Read -Option $OutputPath

    if (-not $OutputPath) {
        Write-Host "FILENAME: Autogenerated" -ForegroundColor Yellow
    } else {
        Write-Host "FILENAME:"$OutputPath -ForegroundColor Yellow
    }

    Write-Host "-----------------------------------"

    [console]::CursorVisible = $True

    Write-Host "Confirm. Create animation?" -ForegroundColor Cyan
    do {
        $Confirm = Read-Host "[yes (y) / no (n)]"
    } while ($Confirm -ne "y" -and $Confirm -ne "yes" -and $Confirm -ne "n" -and $Confirm -ne "no" -and $Confirm -ne "\")

    if ($Confirm -eq "y" -or $Confirm -eq "yes") {
        $OptionsData.Animate = $True
        $OptionsData.Frames = $False
        $OptionsData.InputPath = $InputPath
        $OptionsData.Start = $Start
        $OptionsData.Duration = $Duration
        $OptionsData.NoTimeLimit = $NoTimeLimit
        $OptionsData.Preset = $Preset
        $OptionsData.Size = $Size
        $OptionsData.FPS = $FPS
        $OptionsData.NoLoop = $NoLoop
        $OptionsData.OutputPath = $OutputPath
    } else {
        Start-CreateAnimation -OptionsData $OptionsData
        Return
    }
}

function Start-CreateFrames
{
    param (
        [int32] $CurrentSelection = 0,
        [object] $OptionsData
    )

    Clear-Host
    Show-MenuHeader

    $Key = 0

    [console]::CursorVisible = $True

    Write-Host "GENERATE STILLS:" -ForegroundColor Magenta
    Write-Host "Select output format for image stills." -ForegroundColor Cyan
    do {            
        $InputPath = Read-Host "[Enter video path]"
        Cancel-Read -Option $InputPath
    } while ($InputPath -eq "")

    $InputPath = Trim-String -String $InputPath

    if (-not (Test-Path "$InputPath")) {
        Show-ErrorMessage -Message "Video path `"$InputPath`" doesn't exist. Try again."
    }
    Write-Host "SOURCE:"`"$InputPath`" -ForegroundColor Yellow

    Write-Host "-----------------------------------"

    [console]::CursorVisible = $False

    $Options = 0..3
    $Options[0] = "PNG"
    $Options[1] = "JPG"
    $Options[2] = "WebP"
    $Options[3] = "AVIF"

    Draw-MenuOptions -Options $Options -POS $CurrentSelection

    while ($Key -ne 13 -and $Key -ne 27) {
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode

        if ($Key -eq 13 -and $CurrentSelection -eq 0) {$Format = "png"}
        if ($Key -eq 13 -and $CurrentSelection -eq 1) {$Format = "jpg"}
        if ($Key -eq 13 -and $CurrentSelection -eq 2) {$Format = "webp"}
        if ($Key -eq 13 -and $CurrentSelection -eq 3) {$Format = "avif"}

        $Key, $Options, $CurrentSelection = Get-UpDownControls -Key $Key -Options $Options -CurrentSelection $CurrentSelection

        # ESC KEY
        Invoke-InteractiveEsc
    }

    Write-Host "OUTPUT FORMAT"$Format

    Write-Host "-----------------------------------"

    [console]::CursorVisible = $True

    $Start = Start-GetStartTimecode

    Write-Host "START AT:"$Start -ForegroundColor Yellow

    Write-Host "-----------------------------------"

    $Duration = Start-GetEndTimeCode

    if ($Duration -eq "") {
        Write-Host "DURATION: No Time Limit." -ForegroundColor Yellow
    } else {
        Write-Host "DURATION:"$Duration -ForegroundColor Yellow
    }

    Write-Host "-----------------------------------"

    Write-Host "Confirm. Create frames?" -ForegroundColor Cyan
    do {
        $Confirm = Read-Host "[yes (y) / no (n)]"
    } while ($Confirm -ne "y" -and $Confirm -ne "yes" -and $Confirm -ne "n" -and $Confirm -ne "no" -and $Confirm -ne "\")

    if ($Confirm -eq "y" -or $Confirm -eq "yes") {
        $OptionsData.Frames = $True
        $OptionsData.Animate = $False
        $OptionsData.InputPath = $InputPath
        $OptionsData.Format = $Format
        $OptionsData.Start = $Start
        $OptionsData.Duration = $Duration
        $OptionsData.NoTimeLimit = $NoTimeLimit
    } else {
        Main Start-CreateFrames -OptionsData $OptionsData
        Return
    }
}

function Get-UpDownControls
{
    param (
        [int32] $Key,
        [array] $Options,
        [int32] $CurrentSelection
    )

    # UP ARROW
    if ($Key -eq 38) 
    {            
        $CurrentSelection--
    } 
    
    # DOWN ARROW
    if ($Key -eq 40) 
    {
        $CurrentSelection++
    }

    # DOWN ARROW ON LAST ITEM GOES BACK TO FIRST ITEM
    if ($CurrentSelection -eq $Options.count) 
    {
        $CurrentSelection = 0
    }

    # UP ARROW ON FIRST ITEM GOES DOWN TO LAST ITEM
    if ($CurrentSelection -lt 0) 
    {
        $CurrentSelection = $Options.count - 1
    }

    if ($Key -ne 27 -and $Key -ne 13) 
    {
        try {
            $NewPOS = [System.Console]::CursorTop - $Options.Length
            [System.Console]::SetCursorPosition(0, $NewPOS)
        } catch {
            Clear-Host
            Show-MenuHeader
        }

        Draw-MenuOptions -Options $Options -POS $CurrentSelection
    }

    Return $Key, $Options, $CurrentSelection
}

function Show-Formats
{
    Clear-Host
    Show-MenuHeader

    Write-Host "SUPPORTED ANIMATION INPUT/OUTPUT FORMATS:" -ForegroundColor Cyan
    foreach ($f in $SupportedAnimations) {    
        if($f -eq "webp") {
            Write-Host $f.ToUpper()"*"
        } else {
            Write-Host $f.ToUpper()
        }
    }
    Write-Host "`nSUPPORTED IMAGE INPUT FORMATS (for merging):" -ForegroundColor Cyan
    foreach ($f in $SupportedImages) {
        if ($f -ne "gif") {
            Write-Host $f.ToUpper()
        }
    }
    Write-Host "`nSUPPORTED IMAGE OUTPUT FORMATS (for frames):" -ForegroundColor Cyan
    Write-Host "PNG"
    Write-Host "JPG"
    Write-Host "WebP"
    Write-Host "AVIF"

    Write-Host "`nSUPPORTED VIDEO INPUT FORMATS:" -ForegroundColor Cyan
    foreach ($f in $SupportedVideos) {    
        Write-Host $f.ToUpper()
    }

    Write-Host "`nNOTE: Converting FROM WebP is not supported in this version.`n" -ForegroundColor Yellow
    Pause
    Main
}

function Show-About
{
    Clear-Host
    Show-MenuHeader
    Write-Host "❔ABOUT" -ForegroundColor Cyan
    Write-Host "    Version: $Version (light) - 2023" -ForegroundColor Green
    Write-Host "        GitHub Repo - https://github.com/drequeary/vifpics-light"
    Write-Host
    Write-Host "    Created by - DeAndre Queary"
    Write-Host "        GitHub:     https://github.com/drequeary/"
    Write-Host "        Contact:    contact@deandrequeary.com"
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "🔗 LINKS" -ForegroundColor Cyan
    Write-Host "    ffmpeg                   https://ffmpeg.org/"
    Write-Host "    ffmpeg (windows builds)  https://www.gyan.dev/ffmpeg/builds/"
    Write-Host "    ffprobe                  https://ffmpeg.org/ffprobe.html"
    Write-Host "    gifski                   https://github.com/ImageOptim/gifski/"
    Write-Host "    apngasm                  https://apngasm.sourceforge.net/"
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "🙏🏾CREDITS" -ForegroundColor Cyan
    Write-Host "    Microsoft Powershell Doc https://learn.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7.4"
    Write-Host "    StackOverflow            "
    Write-Host "    ChatGPT                  https://chat.openai.com/"
    Write-Host
    Write-Host "😭 SPECIAL THANKS" -ForegroundColor Magenta
    Write-Host "    NabiKAZ on GitHub for making video2gif.bat."
    Write-Host "        I originally wrote this entire program in batchscript based on NabiKAZ's video2gif.bat."
    Write-Host "        Then decided to rewrite it in Powershell."
    Write-Host "        https://github.com/NabiKAZ/video2gif"
    Write-Host "        -------------"
    Write-Host "    kornelski for developing Gifski."
    Write-Host "        The main reason I wrote this script was because I couldn't get gifski to build with"
    Write-Host "        the video feature built-in. But gifski is a dope tool. <3"
    Write-Host "        https://github.com/kornelski/`n"
    Write-Host "        Fun fact: Vifpics was oriignally called Vifski. But I figured the name was"
    Write-Host "                  wouldn't work well for SEO given it sounded too close to Gifski. 🤷🏾‍♂️"       
    Write-Host "        -------------"
    Write-Host "    The following articles on creating high quality GIFs."
    Write-Host "        https://www.bannerbear.com/blog/how-to-make-a-gif-from-a-video-using-ffmpeg/"
    Write-Host
    Write-Host "        https://blog.pkh.me/p/21-high-quality-gif-with-ffmpeg.html/"
    Write-Host "        -------------"
    Write-Host "    All the developers behind ffmpeg and the optional encoders. This script does nothing without them." -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------------------------"
    Write-Host  "⚠️LIMITATIONS" -ForegroundColor Cyan
    Write-Host  "* Converting from and merging WebP is NOT supported." -ForegroundColor DarkRed
    Write-Host  "* Merging GIFs is NOT supported." -ForegroundColor DarkRed
    Write-Host "------------------------------------------------------------------------------"
    Pause
    Main
}

function Draw-MenuOptions
{
    param (
        [array] $Options, 
        [int32] $POS
    )

    for($i = 0; $i -le $Options.Count; $i++) {
        if ($null -ne $Options[$i]) {
            if ($i -eq $POS) {
                Write-Host "➡️"$Options[$i] -ForegroundColor Cyan
            } else {
                Write-Host "  "$Options[$i]
            }
        }
    }
}

function Invoke-InteractiveEsc
{
    if ($Key -eq 27 -or $Key -eq 220) 
    {
        Main
    }
}

<#
    ANIMATION OPTION FUNCTIONS
    ________________________________________________________________________________
#>
function Test-Input
{
    param (
        $InputPath
    )
    
    $InputBasename = ""
    $InputExt = ""
    $InputExtension = ""
    $InputFormat = ""
    $InputType = ""

    if ($InputPath) {
        # Check if input and output are files or folders.
        $InputExt = Split-Path -Path $InputPath -Extension

        if ($InputExt -eq "") {
            $InputType = "dir"
        } else {
            $InputType = "file"
        }

        if ($InputPath.GetType().IsArray) {
            $InputType = "array"
        }

        # End script if input file or folder doesn't exist.
        if (($InputType -eq "file" -or $InputType -eq "dir") -and -not (Test-Path "$InputPath")) { 
            Show-ErrorMessage -Message "Invalid source. Try again."
        }

        # End script if input file or folder doesn't exist.
        if (-not (Test-Path "$InputPath")) { 
            Show-ErrorMessage -Message "Input file or folder doesn't exist. Try again."
        }

        if ($InputType -eq "file") {
            $InputFile = Get-ChildItem -Path $InputPath
            $InputBasename = $InputFile.BaseName
            $InputExtension = $InputFile.Extension    
            $InputFormat = $InputExtension.Remove(0,1)
            $InputDirName = $InputFile.Directory
            $InputDirPath = $InputFile.DirectoryName
            $InputAbsPath = $InputFile.FullName
        }

        if ((-not ($InputFormat -in $SupportedAnimations) -and -not ($InputFormat -in $SupportedVideos)) -and -not $InputType -in $SupportedInputTypes) {
            Show-ErrorMessage -Message "Unsupported source file. Select `"Show Formats`" option to see supported file types."
        }
    }

    $InputData = New-Object PSObject -Property @{
        InputPath = $InputPath
        InputBasename = $InputBasename
        InputExtension = $InputExtension
        InputFormat = $InputFormat
        InputType = $InputType
        InputDirName = $InputDirName
        InputDirPath = $InputDirPath
        InputAbsPath = $InputAbsPath
    }

    Return $InputData
}

function Start-GetStartTimecode
{
    [console]::CursorVisible = $True

    Write-Host "Enter start timecode. Like 1:30 or 1.30. Default: 0:00." -ForegroundColor Cyan
    do {
        $Start = Read-Host "[Enter start timecode]"
        Cancel-Read -Option $Start
    } while ($Start -ne "" -and (-not ($Start -match $TimeCodePattern) -and -not ($Start -match $TimeCodePattern2) -and -not ($Start -match $TimeCodePattern3)))

    $Start = Trim-String -String $Start

    if ($Start -eq "") {
        $Start = "0:00"
    }

    Return $Start
}

function Start-GetEndTimeCode
{
    [console]::CursorVisible = $True

    Write-Host "Enter animation duration in seconds or 0 for no duration limit. Default: 1." -ForegroundColor Cyan
    $Duration = Read-Host "[Enter duration]"
    Cancel-Read -Option $Duration

    if ($Duration -lt 1 -and -not (Test-Integer $Duration)) {
        $Duration = 1
    }

    if (-not (Test-Integer $Duration)) {
        $Duration = 1
    }

    $Duration = Trim-String -String $Duration

    Return $Duration
}

function Set-Timestamps
{
    param (
        [object] $InputData,
        [object] $OptionsData,
        [string] $OutputFormat
    )
    
    $Start = $OptionsData.Start
    $Duration = $OptionsData.Duration

    # Set timestamps.
    if ($Duration -eq "" -and $To -eq "") {
        $Duration = 1
    }

    if ($OptionsData.NoTimeLimit -and (-not $Duration -or $Duration -lt 1)) {
        $Duration = ""
    }

    # Set start and end stamps for animations.
    $Start = "$Start".replace(".", ":")
    $Duration = "$Duration".replace(".", ":")
    $ToType = "-t"

    if ($Start -and $Duration) {

        $TimeRange = "-ss $Start $ToType $Duration".Split(" ") 

    } elseif ($Start -and $Duration -eq "") {

        $TimeRange = "-ss $Start".Split(" ") 

    } elseif ($Start -eq "" -and $Duration) {

        $TimeRange = "-ss 0.00 $ToType $Duration".Split(" ") 

    }

    if ($Start -and $OptionsData.NoTimeLimit -or $InputData.InputFormat -in $SupportedImages) {
        $TimeRange = "-ss $Start".Split(" ") 
    }

    $TimestampsData = New-Object PSObject -Property @{
        Start = $Start
        Duration = $Duration
        ToType = $ToType
        TimeRange = $TimeRange
    }

    Return $TimestampsData
}

function Set-EncoderPreset
{
    param (
        [object] $OptionsData
    )

    if ($OptionsData.Preset -eq "standard" -or -not $OptionsData.Preset) {
        Write-Host "PRESET: Animated GIF (standard)" -ForegroundColor Cyan
        $OptionsData.Encoder = "ffmpeg"
        $OptionsData.NoFilter = $True
    } elseif ($OptionsData.Preset -eq "hq") {
        Write-Host "PRESET: Animated GIF (high quality)" -ForegroundColor Cyan
        $OptionsData.Encoder = "ffmpeg"
        $OptionsData.NoFilter = $False
    } elseif ($OptionsData.Preset -eq "best") {
        Write-Host "PRESET: Animated GIF (best quality)" -ForegroundColor Cyan
        $OptionsData.Format = "gif"
        $OptionsData.Encoder = "gifski"
        $OptionsData.NoFilter = $True
        $OptionsData.GifskiQuality = 100
    } elseif ($OptionsData.Preset -eq "webp") {
        Write-Host "PRESET: Animated WebP" -ForegroundColor Cyan
        $OptionsData.Format = "webp"
        $OptionsData.Encoder = "ffmpeg"
        $OptionsData.WebpCompression = 4
        $OptionsData.WebpQuality = 75
    } elseif ($OptionsData.Preset -eq "png") {
        Write-Host "PRESET: Animated PNG (APNG)" -ForegroundColor Cyan
        $OptionsData.Format = "apng"
        $OptionsData.Encoder = "ffmpeg"
    } elseif ($OptionsData.Preset -eq "pngopt") {
        Write-Host "PRESET: Animated PNG (APNG)" -ForegroundColor Cyan
        $OptionsData.Format = "apng"
        $OptionsData.Encoder = "apngasm"
    } elseif ($OptionsData.Preset -eq "avif") {
        Write-Host "PRESET: Animated AVIF (SVT medium encode)" -ForegroundColor Cyan
        $OptionsData.Format = "avif"
        $OptionsData.Encoder = "ffmpeg"
        $OptionsData.LibSVT = $True
        $OptionsData.AVIFQ = 8
        $OptionsData.CRF = 21
        $OptionsData.FilmGrain = 8
    } elseif ($OptionsData.Preset -eq "hq-avif") {
        Write-Host "PRESET: Animated AVIF (AOM slow encode)" -ForegroundColor Cyan
        $OptionsData.Format = "avif"
        $OptionsData.Encoder = "ffmpeg"
        $OptionsData.LibAOM = $True
        $OptionsData.AVIFQ = 4
        $OptionsData.CRF = 21
        $OptionsData.FilmGrain = 8
    } elseif ($OptionsData.Preset -eq "mp4") {
        Write-Host "PRESET: MP4 Video" -ForegroundColor Cyan
        $OptionsData.Format = "mp4"
        $OptionsData.Encoder = "ffmpeg"
        $OptionsData.CRF = 21
    } elseif ($OptionsData.Preset -eq "mkv") {
        Write-Host "PRESET: MP4 Video" -ForegroundColor Cyan
        $OptionsData.Format = "mkv"
        $OptionsData.Encoder = "ffmpeg"
        $OptionsData.CRF = 21
    } elseif ($OptionsData.Preset -eq "webm") {
        Write-Host "PRESET: WebM Video" -ForegroundColor Cyan
        $OptionsData.Format = "webm"
        $OptionsData.Encoder = "ffmpeg"
    }
}

function Set-SizePreset
{
    param (
        [object] $OptionsData
    )

    if ($OptionsData.Size -eq "tiny") { 
        $OptionsData.Width = 16; $OptionsData.Height = 16; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "icon") { 
        $OptionsData.Width = 32; $OptionsData.Height = 32; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "big-icon") { 
        $OptionsData.Width = 64; $OptionsData.Height = 64; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "small") { 
        $OptionsData.Width = 128; $OptionsData.Height = 128; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "medium") { 
        $OptionsData.Width = 256; $OptionsData.Height = 256; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "big" -or $OptionsData.Size -eq "large") { 
        $OptionsData.Width = 512; $OptionsData.Height = 512; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "web") { 
        $OptionsData.Width = 640; $OptionsData.Height = 360; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "sd") { 
        $OptionsData.Width = 640; $OptionsData.Height = 480; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "hd") {
        $OptionsData.Width = 1280; $OptionsData.Height = 720; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "fhd") { 
        $OptionsData.Width = 1920; $OptionsData.Height = 1080; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "2k") { 
        $OptionsData.Width = 2560; $OptionsData.Height = 1440; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "4k") { 
        $OptionsData.Width = 3840; $OptionsData.Height = 2160; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "8k") { 
        $OptionsData.Width = 7680; $OptionsData.Height = 4320; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "emote") { 
        $OptionsData.Width = 128; $OptionsData.Height = 128; $OptionsData.NoAutoScale = $True
    } elseif ($OptionsData.Size -eq "wide-emote") { 
        $OptionsData.Width = 336; $OptionsData.Height = 128; $OptionsData.NoAutoScale = $True
    } else {
        $OptionsData.Width = -1; $OptionsData.Height = -1
    }
}

function Set-AnimationOptions 
{
    param (
        [object] $OptionsData
    )

    # Set resolution and image adjustments
    $FPS = $OptionsData.FPS
    $Width = $OptionsData.Width
    $Height = $OptionsData.Height
    
    if ($OptionsData.NoAutoScale) {
        $OptionsData.Resolution = "fps=$FPS,scale=-2:$Height"
    } else {
        $OptionsData.Resolution = "fps=$FPS,scale=$Width"+":"+"$Height"+":force_original_aspect_ratio=decrease:flags=lanczos"
    }
}

function Set-LoopOption
{
    param (
        [object] $OptionsData,
        [string] $OutputFormat,
        [string] $Encoder
    )

    # Infinite looping.
    if ($OutputFormat -eq "gif" -and (-not $OptionsData.NoLoop)) { $OptionsData.LoopOption = "-loop -0".Split(" ") }
    if ($OutputFormat -eq "gif" -and $Encoder -eq "gifski" -and (-not $OptionsData.NoLoop)) { $OptionsData.LoopOption = "--repeat 0".Split(" ") }
    if ($OutputFormat -eq "webp" -and (-not $OptionsData.NoLoop)) { $OptionsData.LoopOption = "-loop 65535".Split(" ") }
    if (($OutputFormat -eq "png" -or $OutputFormat -eq "apng") -and (-not $OptionsData.NoLoop)) { $OptionsData.LoopOption = "-plays 0".Split(" ") }
    if (($OutputFormat -eq "png" -or $OutputFormat -eq "apng") -and $Encoder -eq "apngasm" -and (-not $OptionsData.NoLoop)) { $OptionsData.LoopOption = "-l0" }
    if ($OutputFormat -eq "avif" -and (-not $OptionsData.NoLoop)) { $OptionsData.LoopOption = "-loop 0".Split(" ") }

    # No looping.
    if ($OutputFormat -eq "gif" -and $OptionsData.NoLoop) { $OptionsData.LoopOption = "-loop -1".Split(" ") }
    if ($OutputFormat -eq "gif" -and $Encoder -eq "gifski" -and $OptionsData.NoLoop) { $OptionsData.LoopOption = "--repeat -1".Split(" ") }
    if ($OutputFormat -eq "webp" -and $OptionsData.NoLoop) { $OptionsData.LoopOption = "-loop 1".Split(" ") }
    if (($OutputFormat -eq "png" -or $OutputFormat -eq "apng") -and $OptionsData.NoLoop) { $OptionsData.LoopOption = "-plays 1".Split(" ") }
    if (($OutputFormat -eq "png" -or $OutputFormat -eq "apng") -and $Encoder -eq "apngasm" -and $OptionsData.NoLoop) { $OptionsData.LoopOption = "-l1" }
    if ($OutputFormat -eq "avif" -and $OptionsData.NoLoop) { $OptionsData.LoopOption = "-loop 1".Split(" ") }

    Return $OptionsData.LoopOption
}

<#
    TASK FUNCTIONS
    ________________________________________________________________________________
#>
function New-Animation
{
    param (
        [object] $InputData,
        [object] $OptionsData,
        [object] $TimestampsData
    )

    begin {
        Write-Host "CREATING ANIMATION" -ForegroundColor Magenta
        Start-Sleep 1

        # Check input
        if (-not ($InputData.InputFormat -in $SupportedAnimations) -and -not ($InputData.InputFormat -in $SupportedVideos)) {
            Show-ErrorMessage -Message "Input must be an animated image or video file."
        }

        $InputPath = $InputData.InputPath
        $Timerange = $TimestampsData.TimeRange

        $OutputData = Get-OutputFile -InputData $InputData -OptionsData $OptionsData
        $OutputPath = $OutputData.OutputPath
        $OutputFormat = $OutputData.Format

        # Check output format.
        if (-not ($OutputFormat -in $SupportedAnimations) -and -not ($OutputFormat -in $SupportedVideos)) {
            Show-ErrorMessage -Message "'$OutputFormat' is not image/video output format."
        }

        Start-RemoveExistingOutput
        
        New-TempFolder
    }

    process {
        $Filters = Set-Filter -InputData $InputData -OptionsData $OptionsData -TimestampsData $TimestampsData -OutputFormat $OutputFormat 

        if ($OptionsData.Encoder -eq "ffmpeg") {
            $LoopOption = Set-LoopOption -OptionsData $OptionsData -OutputFormat $OutputFormat -Encoder $OutputData.Encoder
            
            if ($OutputFormat -eq "webp") {
                Write-Host "Creating animated WebP (w/ ffmpeg)..." -ForegroundColor Cyan
                Start-Sleep 1
    
                & $ffmpeg $TimeRange -i "$InputPath" $Filters $LoopOption -compression_level $OptionsData.WebpCompression -qscale $OptionsData.WebpQuality -y "$TempPath\animated.webp"
            } elseif ($OutputFormat -eq "png" -or $OutputFormat -eq "apng") {
                Write-Host "Creating animated PNG (w/ ffmpeg)..." -ForegroundColor Cyan
                Start-Sleep 1
    
                & $ffmpeg $TimeRange -i "$InputPath" $Filters $LoopOption -y "$TempPath\animated.apng"

                try {
                    Copy-Item -Path "$TempPath\animated.apng" -Destination "$TempPath\animated.png" -ErrorAction Stop
                } catch {
                    Write-Host "Could not copy PNG output. Check temp folder..." -ForegroundColor DarkRed
                    Pause
                    Invoke-Item "$TempPath\"
                    Pause
                }   
            } elseif ($OutputFormat -eq "avif" -and $OptionsData.LibAOM) {
                Write-Host "Creating animated AVIF (w/ ffmpeg using libaom)..." -ForegroundColor Cyan
                Start-Sleep 1
    
                if (-not $AVIFQ) { $AVIFQ = 8 }
    
                & $ffmpeg $TimeRange -i "$InputPath" $Filters $LoopOption -c libaom-av1 -cpu-used $OptionsData.AVIFQ -row-mt 1 -g 24 -pix_fmt yuv420p10le -svtav1-params tune=0:film-grain=$OptionsData.FilmGrain -crf $OptionsData.CRF -y "$TempPath\animated.avif"
            } elseif ($OutputFormat -eq "avif") {
                Write-Host "Creating animated AVIF (w/ ffmpeg using libsvtav1)..." -ForegroundColor Cyan
                Start-Sleep 1
    
                if (-not $AVIFQ) { $AVIFQ = 13 }
    
                & $ffmpeg $TimeRange -i "$InputPath" $Filters $LoopOption -c libsvtav1 -preset $OptionsData.AVIFQ -g 24 -pix_fmt yuv420p10le -svtav1-params tune=0:film-grain=$OptionsData.FilmGrain -crf $OptionsData.CRF -y "$TempPath\animated.avif"
            } elseif ($OutputFormat -eq "gif") {
                Write-Host "Creating animated GIF (w/ ffmpeg)..." -ForegroundColor Cyan
                Start-Sleep 1
 
                & $ffmpeg $TimeRange -i "$InputPath" $Filters $LoopOption -y "$TempPath\animated.gif"
            } elseif ($OutputFormat -eq "mp4" -or $OutputFormat -eq "mkv") {
                $CodecName = $OutputFormat.ToUpper()
                Write-Host "Creating $CodecName video (w/ ffmpeg)..." -ForegroundColor Cyan
                Start-Sleep 1

                & $ffmpeg -i "$InputPath" $Filters $LoopOption -c:v libx264 -c:a copy -crf 21 -preset slow -crf $OptionsData.CRF -y "$TempPath\animated.$OutputFormat"
            } elseif ($OutputFormat -eq "webm") {
                Write-Host "Creating WebM video (w/ ffmpeg)..." -ForegroundColor Cyan
                Start-Sleep 1

                & $ffmpeg -i "$InputPath" $Filters $LoopOption -c:v libvpx-vp9 -c:a libopus -crf $OptionsData.CRF -y "$TempPath\animated.webm"
            } 

            Vifpics-CheckError -Message "There was a problem creating animation. See ffmpeg output above for details."
        }

        <#
            Optional encoders
        #>
        if ($OptionsData.Encoder -eq "gifski") {
            Invoke-gifski -InputData $InputData -OptionsData $OptionsData -TimestampsData $TimestampsData -OutputPath "$TempPath\animated.gif"
        }

        if ($OptionsData.Encoder -eq "apngasm") {
            Invoke-apngasm -InputPath $InputPath -OptionsData $OptionsData -TimestampsData $TimestampsData -OutputPath "$TempPath\animated.png"
        }

        Vifpics-CheckError -Message "There was a problem creating animation. See output above for details."

        try {
            Copy-Item -Path "$TempPath\animated.$OutputFormat" -Destination "$OutputPath" -ErrorAction Stop
        } catch {
            Show-ErrorMessage -Message "Could not save $OutputPath. Check Vifpics temp folder in `"$TempPath`"."
        }
    }

    end {
        Return
    }
}

function New-Merge
{
    param (
        [object] $InputData,
        [object] $OptionsData,
        [object] $TimestampsData
    )

    begin {
        Write-Host "MERGING FILES" -ForegroundColor Magenta
        Start-Sleep 1

        $InputPath = $InputData.InputPath
        $InputFormat = $InputData.InputFormat
        $InputType = $InputData.InputType

        $OutputData = Get-OutputFile -InputData $InputData -OptionsData $OptionsData -OutputPath $OutputPath   
        $OutputPath = $OutputData.OutputPath
        $OutputFormat = $OutputData.Format

        Start-RemoveExistingOutput

        New-TempFolder
    }

    process {
        if ($InputType -eq "dir") {
            New-FileListTXT -InputPath $InputPath -InputFromat $InputFormat -InputType $InputType -OptionsData $OptionsData
            $InputPath = "$TempPath\files.txt"            
        }

        if (-not ($OptionsData.MergeFormat -in $SupportedImages) -and -not ($OutputFormat -in $SupportedImages)) {
            Write-Host
            Write-Host "Merging files (no-recode)..." -ForegroundColor Magenta
            Start-Sleep 0.5

            & $ffmpeg $ConcatFlag -i "$InputPath" -c:v copy -c:a copy -movflags +faststart -y -copytb 1 "$OutputPath"
        } else {
            Write-Host
            Write-Host "Merging files (re-encode)..." -ForegroundColor Magenta
            Start-Sleep 0.5
        
            $Filters = Set-Filter -InputData $InputData -OptionsData $OptionsData -TimestampsData $TimestampsData -OutputFormat $OutputFormat 
            
            $LoopOption = Set-LoopOption -OptionsData $OptionsData -OutputFormat $OutputFormat -Encoder $Encoder

            if ($OutputFormat -eq "webp" -and $Libwebp) {
                & $ffmpeg $ConcatFlag -i "$InputPath" $Filters $LoopOption -c libwebp -compression_level $OptionsData.WebpCompression -qscale $OptionsData.WebpQuality -y "$OutputPath"
            } elseif ($OutputFormat -eq "webp") {
                & $ffmpeg $ConcatFlag -i "$InputPath" $Filters $LoopOption -compression_level $OptionsData.WebpCompression -qscale $OptionsData.WebpQuality -y "$OutputPath"
            } elseif ($OutputFormat -eq "avif" -and $LibAOM) {
                if (-not $AVIFQ) { $AVIFQ = 8 }
                & $ffmpeg $ConcatFlag -i "$InputPath" $Filters $LoopOption -c libaom-av1 -cpu-used $OptionsData.AVIFQ -row-mt 1 -g 24 -pix_fmt yuv420p10le -svtav1-params tune=0:film-grain=$OptionsData.FilmGrain -crf $OptionsData.CRF -y "$OutputPath"
            } elseif ($OutputFormat -eq "avif") {
                if (-not $AVIFQ) { $AVIFQ = 13 }
                & $ffmpeg $ConcatFlag -i "$InputPath" $Filters $LoopOption -c libsvtav1 -preset $AVIFQ -g 24 -pix_fmt yuv420p10le -svtav1-params tune=0:film-grain=$OptionsData.FilmGrain -crf $OptionsData.CRF -y "$OutputPath"
            } elseif ($OutputFormat -eq "webm") {
                & $ffmpeg $ConcatFlag -i "$InputPath" $Filters $LoopOption -c:v libvpx-vp9 -c:a libopus -crf $OptionsData.CRF -y "$OutputPath"
            } elseif ($OutputFormat -eq "mp4" -or $OutputFormat -eq "mkv") {
                & $ffmpeg $ConcatFlag -i "$InputPath" $Filters $LoopOption -c:v libx264 -c:a copy -crf $OptionsData.CRF -y "$OutputPath"
            } else {
                & $ffmpeg $ConcatFlag $HardwareDec -i "$InputPath" $HardwareEnc $Filters $LoopOption -crf $OptionsData.CRF -preset slow -movflags +faststart -y "$OutputPath"
                Start-RenameAPNG -OutputPath $OutputPath -OutputFormat $OutputFormat
            }
        }

        Vifpics-CheckError -Message "There was a problem merging files. See ffmpeg output above for details."
    }

    end {
        Return
    }
}

function New-FileListTXT
{
    param (
        [string] $InputFile,
        [string] $InputFormat,
        [string] $InputType,
        [object] $OptionsData
    )

    if (-not (Test-Path "$TempPath\files.txt")) {
        try {
            New-Item -Path "$TempPath\files.txt"
        } catch {
            Show-ErrorMessage -Message "Could not create file to store filenames."
        }
    }

    $ArrayMergeFormat = $False

    if ($InputType -eq "dir") {
        $Files = Get-ChildItem -Path "$InputPath" -File | Sort-Object $ToNatural
    }
        
    foreach ($f in $Files) {
        if (-not (Test-Path $f)) {
            Show-ErrorMessage -Message "$f could not be found. Cannot merge files."
        }

        $f_info = Get-Item -Path $f
        $AbsPath = $f_info.FullName
        $AbsPathExt = $(Split-Path -Path $AbsPath -Leaf).Split(".")[1]  

        # If input type is an array, set the merge format equal to
        # the first file's format.
        if ($ArrayMergeFormat -eq $False) {
            $OptionsData.MergeFormat = $AbsPathExt
            $ArrayMergeFormat = $True
        }

        # If one of the file formats do not match
        # the first file's format, show error.
        if ($AbsPathExt -eq $ArrayMergeFormat) {
            Show-ErrorMessage -Message "Files must be of the same format in order to successfully merge."
        }

        # If a file in an array or folder does isn't supported, show error.
        # Files sould all be the same format.
        if (-not ($AbsPathExt -in $SupportedImages) -and -not ($AbsPathExt -in $SupportedVideos)) {
            Show-ErrorMessage -Message "`"$AbsPath`" is not a supported animated image or video. Cannot continue merge."
        }

        # Gifs cannot be merged.
        if ($AbsPathExt -eq "gif") {
            Show-ErrorMessage -Message "Merging with animated GIFs is currently not supported."
        }

        # Add file path to text file. ffmpeg will use this to merge files.
        if ($AbsPathExt -eq $OptionsData.MergeFormat) {
            Add-Content -Path "$TempPath\files.txt" -value "file `'$Abspath`'"

            # Images won't merge correctly without adding duration to frame.
            if ($OptionsData.MergeFormat -in $SupportedImages) {
                Add-Content -Path "$TempPath\files.txt" -value "duration 0.03333"
            }
        }
    }
}

function New-Frames
{
    param (
        [object] $InputData,
        [object] $OptionsData,
        [object] $TimestampsData
    )

    begin {
        Write-Host
        Write-Host "GENERATING FRAMES" -ForegroundColor Magenta
        Start-Sleep 1

        # Check input.
        if (-not ($InputData.InputFormat -in $SupportedAnimations) -and -not ($InputData.InputFormat -in $SupportedVideos)) {
            Show-ErrorMessage -Message "Input file needs to be an animated image or video file."
        }

        if ($InputData.InputFormat -eq "webp") {
            Show-ErrorMessage "This version of Vifpics cannot convert animated WebP to other formats."
        }

        $OutputFormat = $OptionsData.Format

        # Check output format.
        if ($OutputFormat -ne "png" -and $OutputFormat -ne "jpg" -and $OutputFormat -ne "webp" -and $OutputFormat -ne "avif") {
            #$OutputFormat = "png"
        }

        $InputPath = $InputData.InputPath
        $InputBasename = $InputData.InputBasename

        $UniqueID = Get-Random
        $FramesFolder = "$InputBasename" + "_frames_" + "$UniqueID"
        $OutputPath = "$PWD\$FramesFolder"
        $FramesName = "frame_"
        $FramesIndex = "%01d"
        $TimeRange = $TimestampsData.TimeRange
    }

    process {        
        $Filters = Set-Filter -InputData $InputData -OptionsData $OptionsData -TimestampsData $TimestampsData -OutputFormat $OutputFormat 

        try {
            New-Item -Path "$OutputPath" -ItemType Directory
        } catch {
            Show-ErrorMessage -Message "Could not create frames folder to store frames in."
        }
    
        if ($OutputFormat -eq "webp") {
            & $ffmpeg $TimeRange -i "$InputPath" $Filters -compression_level $OptionsData.WebpCompression -qscale $OptionsData.WebpQuality -y -c libwebp "$OutputPath\$FramesName$FramesIndex.webp"
        } elseif ($OutputFormat -eq "avif") {
            & $ffmpeg $TimeRange -i "$InputPath" $Filters -c libaom-av1 -cpu-used $OptionsData.AVIFQ -row-mt 1 -g 24 -pix_fmt yuv420p10le -svtav1-params tune=0:film-grain=$OptionsData.FilmGrain -crf $OptionsData.CRF -y "$OutputPath\$FramesName$FramesIndex.avif"
        } else {
            & $ffmpeg $TimeRange -i "$InputPath" $Filters -y "$OutputPath\$FramesName$FramesIndex.$OutputFormat"
        }

        Vifpics-CheckError -Message "Could not create frames. Check ffmpeg output above for details."
    }

    end {
        Return
    }
}

function Start-RemoveExistingOutput
{
    # Ask to override when creating a file.
    if (Test-Path $OutputPath) {
        do {
            Write-Host "$OutputPath already exists. Overrite?" -ForegroundColor DarkRed
            $Confirm = Read-Host "[no (n) / yes (y)]"
        } while ($Confirm -ne "" -and $Confirm -ne "y" -and  $Confirm -ne "yes" -and $Confirm -ne "n" -and  $Confirm -ne "no")

        if ($Confirm -eq "y" -or $Confirm -eq "yes") {

            try {
                Remove-Item -Path "$OutputPath" -Force
            } catch {
                Write-Host "Could not remove existing file..."
                Main
            }

        } else {
            Write-Host "Cancelled." -ForegroundColor DarkRed
            Main
        }
    }
}

function Start-RenameAPNG
{
    param (
        [string] $OutputPath,
        [string] $OutputFormat
    )

    if ((Test-Path "$OutputPath") -and $OutputFormat -eq "apng") {
        $OutputPath = Get-ChildItem -Path $OutputPath
        $OutputBasename = $OutputPath.BaseName
        $OutputExtension = $OutputPath.Extension

        if ($OutputExtension) {
            try {
                Copy-Item "$OutputPath" -Destination "$OutputBasename.png" -ErrorAction Stop
                Remove-Item "$OutputPath"
            } catch {
                Write-Host "Could not make normal PNG copy of APNG." -ForegroundColor DarkRed
                Pause
            }                        
        }
    }
}

<#
    GENERAL PROGRAM FUNCTIONS
    ________________________________________________________________________________
#>
function Invoke-gifski
{
    param (
        [object] $InputData,
        [object] $OptionsData,
        [object] $TimestampsData,
        [string] $OutputPath
    )

    begin {
        $InputPath = $InputData.InputPath
        $Timerange = $TimestampsData.TimeRange
        $Resolution = $OptionsData.Resolution
        $Width = $OptionsData.Width
        $Height = $OptionsData.Height
    }

    process {
        Write-Host "Generating frames for gifski..." -ForegroundColor Blue
        Start-Sleep 0.5
        
        New-FramesFolder

        & $ffmpeg $TimeRange -i "$InputPath" -vf $Resolution -y "$TempPath\frames\frame_%01d.png"

        Vifpics-CheckError -Message "There was a problem generating frames. See output ffmpeg above for details."

        Write-Host "Creating higher quality animated GIF (w/ gifski)..." -ForegroundColor Cyan
        Start-Sleep 0.5
        
        # Adjust for Gifski resolution.
        $GifskiRes = ""

        # Gifski default resolution.
        if ($Width -gt 0 -and (Test-Integer $Width)) { $GifskiRes = "--width $Width" }
        if ($Width -gt 0 -and $Height -gt 0 -and (Test-Integer $Width)) { $GifskiRes = "--width $Width --height $Height".Split(" ") }

        $HasFfprobe = Test-Command "ffprobe"

        if (-not $HasFfprobe -and $Width -eq "-1" -and $Height -eq "-1") {
            Write-Host "`nffprobe wasn't found or is executable. Using default gifski resolution..." -ForegroundColor DarkRed
            Start-Sleep 1.5
        } else {
            $Codec = Get-CodecInfo -InputPath $InputPath
            
            # Use ffprobe to get original resolution for gifski encoding.
            if ($Codec -ne @{}) {
                if ($Width -le 0 -and $Codec.streams[0].width) { 
                    $GifskiRes = "--width "+$Codec.streams[0].width
                }

                if ($Width -le 0 -and ($Codec.streams[0].width -gt 0) -and ($Codec.streams[0].height -gt 0)) { 
                    $GifskiRes = "--width "+$Codec.streams[0].width+" --height "+$Codec.streams[0].height
                }    

                if ($Width -le 0 -and $Codec.streams[1].width -gt 0) { 
                    $GifskiRes = "--width "+$Codec.streams[1].width
                }

                if ($Width -le 0 -and ($Codec.streams[1].width -gt 0 -or $Codec.streams[1].height -gt 0)) { 
                    $GifskiRes = "--width "+$Codec.streams[1].width+" --height "+$Codec.streams[1].height
                }   
            }
        }

        $GifskiRes = $GifskiRes.Split(" ")

        if (-not $GifskiRes) {
            Clear-Variable GifskiRes
        }


        $GifskiQuality = $OptionsData.GifskiQuality
        $LoopOption = Set-LoopOption -OptionsData $OptionsData -OutputFormat $OutputFormat -Encoder "gifski"

        & $gifski $GifskiRes --quality $GifskiQuality --fps $OptionsData.FPS $LoopOption --fast -o "$OutputPath" "$TempPath\frames\frame_*.png"

        Vifpics-CheckError -Message "There was an error creating animation. See gifkski output above for details."
    }

    end {
        Return
    }
}

function Get-OutputFile
{
    param (
        [object] $InputData,
        [object] $OptionsData
    )

    # Set filename template.
    $DefaultFilename = "vifpics_"

    # Generate default filename for when no output
    # filename is specified.
    $UniqueID = Get-Random

    if (-not $OptionsData.OutputPath) {
        $OutputPath = "$PWD\$DefaultFilename$UniqueID"    
    } else {
        $OutputPath = $OptionsData.OutputPath
    }

    $OutputFormat = $OptionsData.Format

    # All animated PNGs will output as APNG in temp, then
    # renamed as PNG after copying to final output destination.
    if ($OutputFormat -eq "png" -and -not $OptionsData.Frames) {
        $OutputFormat = "apng"
    }

    # Output format defaults to GIF.
    if (-not ($OutputFormat -in $SupportedAnimations) -and -not ($OutputFormat -in $SupportedVideos)) {
       $OutputFormat = "gif"
    }    

    $OutputPath = "$OutputPath.$OutputFormat"

    $OutputData = New-Object PSObject -Property @{
        OutputPath = $OutputPath
        Format = $OutputFormat
    }

    Return $OutputData
}

function Invoke-apngasm
{
    param (
        [object] $InputPath,
        [string] $OutputPath,
        [object] $OptionsData,
        [object] $TimestampsData
    )

    begin {
        $Resolution = $OptionsData.Resolution
    }

    process {
        Write-Host "Creating optimized animated PNG (w/ apngasm)..." -ForegroundColor Cyan
        Start-Sleep 0.5
        Write-Host "Generating frames..." -ForegroundColor Blue
        Start-Sleep 0.5

        New-FramesFolder

        $Timerange = $TimestampsData.TimeRange
        & $ffmpeg $Timerange -i "$InputPath" -vf $Resolution -y "$TempPath\frames\frame-%04d.png"

        Vifpics-CheckError -Message "There was a problem generating frames. Check ffmpeg output above for details."

        Write-Host "Generating PNG..." -ForegroundColor Cyan
        Start-Sleep 0.5

        $LoopOption = Set-LoopOption -OptionsData $OptionsData -OutputFormat $OutputFormat -Encoder "apngasm"

        & $apngasm $OutputPath "$TempPath\frames\frame-*.png" 1 $OptionsData.FPS $LoopOption $OptionsData.PNGcompressMethod -kc

        Vifpics-CheckError -Message "There was a problem creating file. Check apngasm output above for details."
    }

    end {
        Return
    }
}

function Get-CodecInfo
{
    param (
        [string] $InputPath
    )

    $Codec = @{}

    if ($HasFfprobe) {
        if (-not (Test-Path "$TempPath\media.json")) {
            try {
                New-Item "$TempPath\media.json" -ItemType File -ErrorAction Stop
            } catch {
                Show-ErrorMessage -Message "Could not create metadata file."
            }
        }
    
        & $ffprobe -v quiet -print_format json -show_format -show_streams "$InputPath" > "$TempPath\media.json"
    
        $ffprobeJSON = Get-Content "$TempPath\media.json" -Raw
    
        if (-not ($?)) {
            Write-Host
            Write-Host "There was a problem extracting file details with ffprobe..." -ForegroundColor DarkRed
            Start-Sleep 1.5
        } else {
            $Codec = $ffprobeJSON | ConvertFrom-Json
        }
    }

    Return $Codec
}

function Set-Filter
{
    param (
        [object] $InputData,
        [object] $OptionsData,
        [object] $TimestampsData,
        [string] $OutputFormat
    )

    $InputPath = $InputData.InputPath

    # Apply image adjustments and resolution in initial filter.
    $Resolution = $OptionsData.Resolution
    $Dither = $OptionsData.Dither

    $Filters = "-vf $Resolution"

    if ($OptionsData.NoFilter -eq $False -and $OutputFormat -eq "gif") {

        # Apply default vifpics filter.
        if (-not $OptionsData.Palettegen -and ($InputData.InputFormat -in $SupportedAnimations -or $InputData.InputFormat -in $SupportedVideos)) {
            Write-Host "Creating image palette." -ForegroundColor Green
            Start-Sleep 0.5
            Write-Host "Applying high quality filter (lavfi)..." -ForegroundColor Cyan
            Start-Sleep 0.5

            $Palette = "$TempPath\palette.png".Split(" ")
            $Filters = "-i $Palette -lavfi $Resolution[x];[x][1:v]paletteuse=dither=$Dither"

            & $ffmpeg $TimestampsData.TimeRange -i "$InputPath" -vf palettegen=max_colors=256 -y "$Palette"

            Vifpics-CheckError "Could not generate filter palette. Try using -palettgen option."

            if ((Test-Path $Palette) -eq $False) {
                Write-Host "There was a problem creating color palette. Using Palettegen filter instead..." -ForegroundColor DarkRed
                Start-Sleep 1.5
                $OptionsData.Palettegen = $True
            }
        }

        # Apply palettegen filter.
        if ($OptionsData.Palettegen) {
            Write-Host "Applying high quality filter (filter_complex)..." -ForegroundColor Cyan
            Start-Sleep 1
            $Filters = "-filter_complex [0:v],$Resolution,split[a][b];[a]palettegen[p];[b][p]paletteuse;"
        }
    }

    Return $Filters.Split(" ")
}

function New-TempFolder
{
    # Clear temp folder.
	if (-not (Test-Path "$TempPath")) {
		Write-Host "Creating new temp..." -ForegroundColor Cyan
        Start-Sleep 0.5
        try {
            New-Item "$TempPath" -ItemType Directory -ErrorAction SilentlyContinue
        } catch {
            Write-Host "Could not create temp folder. Output may be wrong..." -ForegroundColor DarkRed
            Start-Sleep 2
        }
	} else { 
        try {
            Remove-Item "$TempPath\*" -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Could not clear temp folder. Output may be wrong." -ForegroundColor DarkRed
            Start-Sleep 2
        }
    }
}

function New-FramesFolder
{
    if (-not (Test-Path "$TempPath\frames")) { 
        Write-Host "Creating frames folder..." -ForegroundColor Cyan
        Start-Sleep 0.5

        try {
            New-Item "$TempPath\frames\" -ItemType Directory -ErrorAction Stop
        } catch {
            Show-ErrorMessage -Message "Could not create frames folder to store frames in."
        }
    } else {
        try {
            Remove-Item "$TempPath\frames\*" -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Could not clear frames folder folder. Output may be wrong..." -ForegroundColor DarkRed
            Start-Sleep 2
        }
    }
}

function Test-Command
{
    param (
        [string] $Command
    )

    if ($null -ne (Get-Command "$Command" -ErrorAction SilentlyContinue) -or (Test-Path "$PSScriptRoot\$Command.exe")) { 
        Return $True
    } else {
        Return $False
    }
}

function Cancel-Read
{
    param (
        [string] $Option
    )

    if ($Option -eq "\") {
        Main
    }
}

function Test-Integer {
    param (
        [string] $StringInput
    )
    
    Return $StringInput -match '^\d+$'
}

function Trim-String
{
    param (
        [string] $String
    )

    $String = $String.trim('"')
    $String = $String.trim("'")

    Return $String
}

function Show-ErrorMessage
{
    param (
        [string] $Message
    )

    if ($Message) {
        Write-Host "VIFPICS ERROR: $Message" -ForegroundColor Red
        Pause
        Main
    }
}

function Vifpics-CheckError
{
    param (
        [string] $Message
    )

    if (-not ($?)) {
        Write-Host "VIFPICS ERROR: $Message" -ForegroundColor Red
        Pause
        Main
    }
}

Main