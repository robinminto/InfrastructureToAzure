Configuration WinVMConfiguration
{

   
    WindowsFeature WebServerRole
    {
      Name = "Web-Server"
      Ensure = "Present"
    }
  
    Script InstallWebsite
    {
        TestScript = {
            Test-Path "C:\inetpub\Wwwroot\index.html"
        }
        SetScript ={
            $source = "https://github.com/marrobi/DevOpsDemos/raw/master/InfrastructureToAzure/Infrastructure/Websites/WindowsWebsite.zip"
  
           Invoke-WebRequest $source -OutFile "$env:TMP\website.zip"
        
           Expand-Archive  -Path "$env:TMP\website.zip" -DestinationPath "c:\inetpub\wwwroot"
       }

        GetScript = {@{Result = "InstallWebsite"}}
        DependsOn = "[WindowsFeature]WebServerRole"
    }
 
}