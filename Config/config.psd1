@{
    Data = @{
        # List the items that will appear in the Source and Destination ComboBoxes
        # The list should be comma separated with each value in quotes ('' or "")
        # Example: NetworkList = @('Network1', 'Network2')
        NetworkList = @('Corporate', 'Customer')
        # List of media types available in the ComboBox.
        # The list should be comma separated with each value in quotes ('' or "")
        MediaType = @('Apricorn', 'Blu-ray', 'CD', 'DVD', 'HDD', 'MicroSD', 'SSD', 'USB-Flash')
        # List the Media ID's to include in the ComboBox.
        # The list should be comma separated with each value in quotes ('' or "")
        MediaID = @('')
    }
    Output = @{
        # The location to save the Transfer log and File List Log.
        # DTA users need to have write access to this folder.
        LogFolder = "C:\temp\logs"
        # Determines if a subfolder with the current 4-digit year will be created in the log output folder.
        # If '$true', the subfolder will be created.
        YearSubFolder = $true
        # The name of the file used for logging transfers. Do not include an extension as it will be added automatically.
        TransferLogName = "TransferLog"
        FileLog = @{
            Order = 'Date', 'Username', 'TransferType', 'Network'
            # Configures the delimiter used for separating sections in the output filename
            Delimiter = '_'
            # Configure the date format used in the output filename
            DateFormat = 'yyyyMMdd'
        }
    }
}