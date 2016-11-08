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
#	   Mode = "644"        
   	Type = "file"
#	   DependsOn = "[nxPackage]httpd"
	}


#	nxArchive SyncWebDir
#	{
#	   SourcePath = "/var/tmp/LinuxWebsite.zip"
#	   DestinationPath = "/var/www/html"
#	   Force = $true
#	   DependsOn = "[nxFile]SyncArchiveFromWeb"
#	}
}

