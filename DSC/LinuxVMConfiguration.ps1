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
	 

	 	SourcePath = "https://github.com/marrobi/InfrastructureToAzure/raw/master/Websites/LinuxWebsite.zip"
	   	DestinationPath = "/var/tmp/LinuxWebsite.zip"
		Type = "file"

	}


	nxArchive SyncWebDir
	{
	   SourcePath = "/var/tmp/LinuxWebsite.zip"
	   DestinationPath = "/var/www/html"
	   Force = $true
	   DependsOn = '[nxFile]SyncArchiveFromWeb','[nxPackage]httpd'
	}
}

