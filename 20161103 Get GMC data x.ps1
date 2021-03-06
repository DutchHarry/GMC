<#
Errors
surname, given names mix up in data

Purpose: 
  extract GMC data using a list og GMC numbers from file

Notes
First tricky bit is to properly control IE.
Seems only possible by checking page title (in this case), so you must first let IE do its thing, then check if there is a title, and then check it's the right title.
Obviously it hangs as long as it doesn't see the right title.
So needs something written to screen to show it's still moving. Did that with Write-Host, as Write-Progress has far too much overhead.
Since it still breaks occasionally the main loop is encapsulated in an all loop that restarts IE and continues where it broke previously
You should see erroring GMC numbers in the error file; just retry them later.

Second tricky bit is the GMC webpage changing, both "id"-s as well as enumerations, so you may have to inspect the elements (F12 in IE) for correct "id" or check the enumeration in the powershell window

Output:
  Delimited file with delimiter "�"
  The History column in turn is delimited again with delimiter "|"
  
  Probably should do that in JSON someday

Inputs : indicated with # CHANGE # below
  Optional: a different window title
  A starting number (the first one in file with GMC numbers), or the last one on screen after Ctrl-C
  A file with GMC numbers
  An output file name
  An output error file name

#>

# change window title
$host.ui.RawUI.WindowTitle = "Extract GMC numbers x"                            <# CHANGE #>
# for restart; number to cycle forward to; should be first number in file on first run
$gmctocheck1 = "0060820"                                                        <# CHANGE #>

# sure all loop fires
$gmctocheck = $gmctocheck1.PadLeft(7,'0')
$line = "somethingtostartwith" # needs initialisation as it tests for $line -eq $null later

# file with GMC numberslinks
$inputfile = "S:\_ue\GMCnumbers_x.csv"                                          <# CHANGE #>
# output files
$outputfile = "S:\_ue\GMCdata_x.csv"                                            <# CHANGE #>
$erroroutputfile = "S:\_ue\errorGMCdata_x.csv"                                  <# CHANGE #>
# header in output
#Add-Content $outputfile "GMCNumber�GivenNames�Surname�Gender�Status�PrimaryMedicalQualification�ProvisionalRegistrationDate�FullRegistrationDate�SpecialistRegisterEntryDate�GPRegistrationDate�RevalidationInformation�ExtractionDateTime�History"
#Add-Content $erroroutputfile "GMCNumber"

for(;;) { # all loop
  # stop if nothing left to do
  if ($line -eq $null){break}

  $gmctocheckold = $gmctocheck
  $justrestarted = $true

  $counter = 0
  $reader = New-Object System.IO.StreamReader($inputfile)
  # initiate IE
  $ie  = New-Object -com "InternetExplorer.Application"
#  $ie.Visible = $true
  $url = "http://webcache.gmc-uk.org/gmclrmp_enu/start.swe?"
  $ie.navigate($url)
  # now wait till IE has got the page
  while ($ie.busy) {start-sleep -milliseconds 20}
  while ($ie.ReadyState -ne 4) {start-sleep -milliseconds 20} 
  # cannot use any test that requires something to exist before it exists, thus
  # make sure the page has a title
  while ($ie.document.title -eq $null) {start-sleep -milliseconds 20}    
#  $ie.document.title
  # check the title is what it should be
  while (!($ie.document.title -eq "List of Registered Medical Practitioners `| Doctor Search")) {start-sleep -milliseconds 20}    

  $nl = [Environment]::NewLine
  $data = $null
  $errordata = $null

  try { # 1st try
    for(;;) {
      $line = $reader.ReadLine()
      if ($line -eq $null){Return}
      # process the line
      # gmc needs 7 digits
      $gmctocheck = $line.PadLeft(7,'0')
      # cycle forward to starting number after restart
      if ($justrestarted -eq $true) {
        if ($gmctocheck -ne $gmctocheckold){
          continue
        }else{
          $justrestarted = $false
        }
      }
      try { # 2nd try
        $ie.document.frames.item(0).document.frames.item(1).document.getElementById("gmcrefnumber").Value = $gmctocheck
        $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_3_1_10_0").Click()
        while ($ie.ReadyState -ne 4) {start-sleep -milliseconds 20} 
        while ($ie.busy) {start-sleep -milliseconds 20}
        while ($ie.document.title -eq $null) {start-sleep -milliseconds 20}    
#        $ie.document.title
        while (!( ($ie.document.title -eq "List of Registered Medical Practitioners `| Doctor Details") -or ($ie.document.title -eq "List of Registered Medical Practitioners `| Search Results") ) ) {start-sleep -milliseconds 20}    

        # these are the not found cases
        # if 1
        if ($ie.document.title -eq "List of Registered Medical Practitioners `| Search Results") {
          # goto search again
          $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_4_1_3_0").Click()
        }else{
          # if 2
          if ( $ie.document.title -eq "List of Registered Medical Practitioners `| Doctor Details" ) {  
            # these sre the cases where the GMC number was found
            $extractdate = $null
            # Date will have a trailing space if the day<10
            $extractdate = ($ie.document.frames.item(0).document.frames.item(1).document.getElementsByClassName("tablebodypaddingtop")[0].innerHTML).Substring(22,23)
            $gmcnumber = $null
            $gmcnumber = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_23_0").innerHTML
            $givennames = $null
            $givennames = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_37_0").innerHTML
            $surname = $null
            $surname = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_36_0").innerHTML
            $gender = $null
            $gender = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_35_0").innerHTML
            $status = $null
            $status = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_11_0").innerHTML

            $primmedqual = $null
            # if more than one qualification they will be delimited by "<br>"
            $primmedqual = $ie.document.frames.item(0).document.frames.item(1).document.getElementsByClassName("tablebodyfields")[13].innerHTML
            $provregdate = $null
            $provregdate = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_24_0").innerHTML
            $fullregdate = $null
            $fullregdate = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_4_0").innerHTML
            $specregentrydate = $null
            $specregentrydate = $ie.document.frames.item(0).document.frames.item(1).document.getElementsByClassName("tablebodyfields")[18].innerHTML
            $gpregdate = $null
            $gpregdate = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_6_0").innerHTML
            $revalinfo = $null
            $revalinfo = $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_2_1_1_0").innerHTML

            # to doctor history
            $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_1_1_4_0").Click()
            while ($ie.ReadyState -ne 4) {start-sleep -milliseconds 20} 
            while ($ie.busy) {start-sleep -milliseconds 20}
            while ($ie.document.title -eq $null) {start-sleep -milliseconds 20}    
  #          $ie.document.title
            while ($ie.document.title -ne "List of Registered Medical Practitioners `| Doctor History") {start-sleep -milliseconds 20}

            # grab table with history
            $listapplettablerows = $null
            $listapplettablerows = $ie.document.frames.item(0).document.frames.item(1).document.getElementsByClassName("listapplettablerows")
            $numcells = ($listapplettablerows | Measure).Count
            $history = $null
            For ($i=0; $i -lt $numcells; $i++){
              $datah = $null
              $datah = $listapplettablerows[$i].innerText
              $history = "$history|$datah"
            }

            # add record to data
            $data = "$data$gmcnumber�$givennames�$surname�$gender�$status�$primmedqual�$provregdate�$fullregdate�$specregentrydate�$gpregdate�$revalinfo�$extractdate�$history$nl"     
            # goto search again
            $ie.document.frames.item(0).document.frames.item(1).document.getElementById("s_1_1_3_0").Click()
          } # if 2 
        } # if 1

        # write number just done, so you can check it's still moving
        Write-Host "$gmctocheck" # faster than progess indicator
        # progress indicator, so we can see it's still working
#        Write-Progress -Activity "Working..." -CurrentOperation "$gmctocheck processing" -Status "Please wait."

        while ($ie.ReadyState -ne 4) {start-sleep -milliseconds 20} 
        while ($ie.busy) {start-sleep -milliseconds 20}
        while ($ie.document.title -eq $null) {start-sleep -milliseconds 20}    
#        $ie.document.title
        while ($ie.document.title -ne "List of Registered Medical Practitioners `| Doctor Search") {start-sleep -milliseconds 20}    
        
      }catch{ # 2nd catch
        $errordata = "$errordata$gmctocheck$nl"
        Write-Host "Error on $gmctocheck"
#        Return #for testing to break out of loop when errors
      } # 2nd try
    } # for loop
  }catch{ # 1st catch
     $errordata = "$errordata$gmctocheck�1st catch$nl"
     Write-Host "Error on 1st catch $gmctocheck"
  } # 1st try

  $ie.Quit()
  $ie = $null
  $reader.Close()
  $reader = $null
  # flush data to file
  Add-Content $outputfile "$data"
  Add-Content $erroroutputfile "$errordata"
  start-sleep -milliseconds 1000 # give it a bit more to be sure it's all closed
  # garbage collector
  [GC]::Collect()
} # for loop all

# flush data to file after Ctrl-C: run this manually if needed
# if IE timed out you may have to close it manually, so make it visible
$ie.visible = $true
Add-Content $outputfile "$data"
Add-Content $erroroutputfile "$errordata"
$ie.Quit()
$ie = $null
$reader.Close()
$reader = $null
# garbage collector
[GC]::Collect()

