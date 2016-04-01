Configuration LinuxVMConfiguration {

	Import-DSCResource -Name nxPackage
	Import-DSCResource -Name nxArchive
    Import-DSCResource -Name nxFile
	
	nxPackage httpd
	{
		Name = "apache2"
		Ensure = "Present"
		}

	nxFile SyncArchiveFromWeb
	{
	   Ensure = "Present"
	   SourcePath = "https://github.com/marrobi/DevOpsDemos/raw/master/InfrastructureToAzure/Infrastructure/Websites/LinuxWebsite.zip"
	   DestinationPath = "/var/tmp/LinuxWebsite.zip"
	   Type = "File"
	   DependsOn = "[nxPackage]httpd"
	}
	nxArchive SyncWebDir
	{
	   SourcePath = "/var/tmp/LinuxWebsite.zip"
	   DestinationPath = "/var/www/html"
	   Force = $true
	   DependsOn = "[nxFile]SyncArchiveFromWeb"
	}
}

