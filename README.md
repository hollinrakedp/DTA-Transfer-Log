# Data Transfer Log Creator
The DTA Transfer Log GUI provides an efficient method for a Data Transfer Agent (DTA) to ensure they record the required information for each data transfer they perform.

## Features
* Creates a log entry within the Transfer Log (.csv) file
* Creates a file listing (.csv) for each transfer logged
* Automatic naming of log files
* Lists files located within archive files (zip)
* Works with nested '.zip' files
* Experimental support for '.tar', '.tar.gz', and '.tgz' files (nested archives is not supported)


## Installation and Configuration
* Copy this project to a location on the DTA Computer.
   * General users should not have write/modify access to this location.
   * DTA Users need to have read access to this location.
* Update the configuration file (config.psd1) to match your environment.
   * General users do not need access to this location.
   * DTA Users need write/modify access to the 'LogFolder' location provided in the configuration file
* Create a new shortcut. Use the following information during creation:
   * Type the location of the item:
      ```powershell
      powershell.exe -WindowStyle Hidden -File C:\Path\To\DTA-GUI.ps1
      ```
   * Type a name for this shortcut:
      * DTA Transfer Log
* An icon file is included in the 'Resources' directory


## Usage


## Tips and Troubleshooting
* For larger installations with multiple DTA computers, use Group Policy to push out the configuration file
