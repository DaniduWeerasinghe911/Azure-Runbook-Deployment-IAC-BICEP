#Test Parameters
# $TimeRange = '6AM-11PM'
# $TimeRange = 'Friday'
# $scheduledays = 'Monday,Tuesday,Wednesday,Thursday,Friday'
$Simulate = $false

Import-Module Az.Accounts
Import-Module Az.Compute
Import-Module Az.Resources
Import-Module Az.DesktopVirtualization

$UTCNow = [System.DateTime]::UtcNow   
$VERSION = "3.0"

# Define function to convert time from UTC to AEST
function Get-AESTTime($UTCNow) {
    $strSourceTimeZone = "UTC"    
    $strDestTimeZone = "AUS Eastern Standard Time"
    $STZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strSourceTimeZone)
    $DTZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strDestTimeZone)
    $LocalTime = [System.TimeZoneInfo]::ConvertTime($UTCNow, $STZ, $DTZ)
    Return $LocalTime
}

# Define function to check current time against specified range

function CheckScheduleEntry ([string]$TimeRange) {    
    # Initialize variables
    $rangeStart, $rangeEnd, $parsedDay = $null
    $localCurrentTime = Get-AESTTime $UTCNow
    $currentTime = Get-AESTTime $UTCNow
    $midnight = $localCurrentTime.AddDays(1).Date            

    try {
        # Parse as range if contains '->'
        if ($TimeRange -like "*-*") {
            $timeRangeComponents = $TimeRange -split "-" | foreach { $_.Trim() }
            if ($timeRangeComponents.Count -eq 2) {
                $rangeStart = Get-Date  $timeRangeComponents[0]
                $rangeEnd = Get-Date $timeRangeComponents[1]
                
                # Check for crossing midnight
                if ($rangeStart -gt $rangeEnd) {
                    # If current time is between the start of range and midnight tonight, interpret start time as earlier today and end time as tomorrow
                    if ($localCurrentTime -ge $rangeStart -and $localCurrentTime -lt $midnight) {
                        $rangeEnd = $rangeEnd.AddDays(1)
                    }
                    # Otherwise interpret start time as yesterday and end time as today   
                    else {
                        $rangeStart = $rangeStart.AddDays(-1)
                    }
                }
                # Check if days are same in UTC and AEST
                if ( ($rangeStart).DayOfWeek -eq $localCurrentTime.DayOfWeek) {
                    $rangeStart = Get-Date  $timeRangeComponents[0]
                    $rangeEnd = Get-Date $timeRangeComponents[1]
                }
                else {

                    $rangeStart = (Get-Date  $timeRangeComponents[0]).AddDays(1)
                    $rangeEnd = (Get-Date $timeRangeComponents[1]).AddDays(1)
                }  
                Write-Output $currentTime
            }
            
            else {
                Write-Output "`tWARNING: Invalid time range format. Expects valid .Net DateTime-formatted start time and end time separated by '-'" 
            }
        }
        # Otherwise attempt to parse as a full day entry, e.g. 'Monday' or 'December 25' 
        else {
            # If specified as day of week, check if today
            if ([System.DayOfWeek].GetEnumValues() -contains $TimeRange) {
                if ($TimeRange -eq $currentTime.DayOfWeek) {
                    $parsedDay = $currentTime.Date
                }
                else {
                    # Skip detected day of week that isn't today
                }
            }
            # Otherwise attempt to parse as a date, e.g. 'December 25'
            else {
                $parsedDay = Get-Date $TimeRange
            }
        
            if ($parsedDay -ne $null) {
                $rangeStart = $parsedDay # Defaults to midnight
                $rangeEnd = $parsedDay.AddHours(23).AddMinutes(59).AddSeconds(59) # End of the same day
            }
        }
    }
    catch {
        # Record any errors and return false by default
        Write-Output "`tWARNING: Exception encountered while parsing time range. Details: $($_.Exception.Message). Check the syntax of entry, e.g. '<StartTime> - <EndTime>', or days/dates like 'Sunday' and 'December 25'"   
        return $false
    }
    
    # Check if current time falls within range
    if ($localCurrentTime -ge $rangeStart -and $localCurrentTime -le $rangeEnd) {
        return $true
    }
    else {
        return $false
    }
    
} 
# End function CheckScheduleEntry

# Function to handle power state assertion for upgraded (AZ module)resource manager VM
function AssertRMVirtualMachinePowerState {
    param(
        [Object]$VirtualMachine,
        [string]$DesiredState,
        [bool]$Simulate
    )

    # Get VM with current status
    $resourceManagerVM = Get-AzVM -ResourceGroupName $VirtualMachine.ResourceGroupName -Name $VirtualMachine.Name -Status
    $currentStatus = $resourceManagerVM.Statuses | where Code -like "PowerState*" 
    $currentStatus = $currentStatus.Code -replace "PowerState/", ""

    # If should be started and isn't, start VM
    if ($DesiredState -eq "Started" -and $currentStatus -notmatch "running") {
        if ($Simulate) {
            Write-Output "[$($VirtualMachine.Name)]: SIMULATION -- Would have started VM. (No action taken)"
        }
        else {
            Write-Output "[$($VirtualMachine.Name)]: Starting VM"
            $resourceManagerVM | Start-AzVM -NoWait
        }
    }
        
    # If should be stopped and isn't, stop VM
    elseif ($DesiredState -eq "StoppedDeallocated" -and $currentStatus -ne "deallocated") {
        if ($Simulate) {
            Write-Output "[$($VirtualMachine.Name)]: SIMULATION -- Would have stopped VM. (No action taken)"
        }
        else {
            Write-Output "[$($VirtualMachine.Name)]: Stopping VM"
            $resourceManagerVM | Stop-AzVM -Force
        }
    }

    # Otherwise, current power state is correct
    else {
        Write-Output "[$($VirtualMachine.Name)]: Current power state [$currentStatus] is correct."
    }
}

function StartShutdown {
    param(
       [string]$subscriptionId
    )

    # Get a list of all VMs in the ResourceGroup
    $resourceManagerVMList = @(Get-AzResource | where { $_.ResourceType -like "Microsoft.Compute/virtualMachines" } | sort Name)

    $currentTime = Get-AESTTime $UTCNow
    Write-Output "Runbook started. Version: $VERSION"
    foreach ($vm in $resourceManagerVMList) {
        $schedulehours = $null
        $scheduledays = $null
        $ManualStart = $null

        # Check for direct tag or group-inherited tag
        if ($vm.Tags -ne $null -and $vm.Tags.containskey('AvailableHours') ) {
            $schedulehours = $vm.Tags.AvailableHours
        }
        if ($vm.Tags -ne $null -and $vm.Tags.containskey('AvailableDays') ) {
            $scheduledays = $vm.Tags.AvailableDays
            Write-Output "[$($vm.Name)]: Found direct VM schedule tag with value: $scheduledays and $schedulehours and $currentTime"
        }
        if ($vm.Tags -ne $null -and $vm.Tags.containskey('ManualStart') ) {
            $manualstart = $vm.Tags.ManualStart
            Write-Output "[$($vm.Name)]: Found VM tag with ManualStart value set to $manualstart VM will be skipped and this tag will be deleted"
        }
        # Check that tag value was succesfully obtained
        if ($schedulehours -eq $null) {
            Write-Output "[$($vm.Name)]: Failed to get tagged schedule for virtual machine. Skipping this VM."
            continue
        } 
        # Parse the hour ranges in the Tag value. Expects a string of comma-separated time ranges, or a single time range
    
        $timeRangeListhours = @($schedulehours -split "," | foreach { $_.Trim() })
        # Parse the Day ranges in the Tag value. Expects a string of comma-separated time ranges, or a single time range
        $timeRangeListDays = @($scheduledays -split "," | foreach { $_.Trim() })
        
        # Check each range against the current time to see if any schedule is matched
        $schedulehoursMatched = $false
        #$matchedhoursSchedule = $null
        $scheduledaysMatched = $false
        #$matcheddaysSchedule = $null
        foreach ($hours in $timeRangeListhours) { 
            if ((CheckScheduleEntry -TimeRange $hours) -eq $true) {
                $schedulehoursMatched = $true
                $matchedSchedulehours = $hours
                break
            }
        }
        foreach ($days in $timeRangeListDays) { 
            if ((CheckScheduleEntry -TimeRange $days) -eq $true) {
                $scheduledaysMatched = $true
                $matchedScheduledays = $days
                break
            }
        }
        # Enforce desired state for group resources based on result.
        if ($schedulehoursMatched -and $scheduledaysMatched) {
            # Schedule is matched. Start the VM if it is stopped. 
            Write-Output "[$($vm.Name)]: Current time [$currentTime] falls within the scheduled available days and hours range [$matchedScheduledays] and [$matchedSchedulehours]"
            AssertRMVirtualMachinePowerState -VirtualMachine $vm -DesiredState "Started"  -ResourceManagerVMList $resourceManagerVMList  -Simulate $Simulate
        }
        else {
            # Schedule not matched. Stop VM if it is running.
            Write-Output "[$($vm.Name)]: Current time falls outside of all scheduled avaialble hours ranges.VM will be shutdown"
            AssertRMVirtualMachinePowerState -VirtualMachine $vm -DesiredState "StoppedDeallocated" -ResourceManagerVMList $resourceManagerVMList -Simulate $Simulate
        }     
    }
}



# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

$AzSubscriptions = get-AzSubscription

foreach ($azSub in $AzSubscriptions) {
    $AzureContext = Set-AzContext -Subscription $azSub.id -DefaultProfile $AzureContext
    StartShutdown
}
Write-Output "Finished processing virtual machine schedules"
 
 
