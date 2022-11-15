#!/usr/bin/perl

##
## Written By: Chris Kloiber
## Date: 7/1/2012
##
## Description:
## Controls Apache vhosts
##

##### VARS (NO trailing slashes) #####

$root_site_path = "/var/www/vhosts"; # Path to vhost content directories
$public_html_dir = ""; # Use a sub dir for site content

$write_to = "vhost"; # Vhost (/etc/httpd/conf.d) or main (add to end of httpd.conf)
$httpd_conf_dir = "/etc/httpd/conf";  # Path to Apache configs
$httpd_file = "httpd.conf"; # Primary apache config file
$vhost_conf_dir = "/etc/httpd/conf/vhosts"; # Path to create Apache config include files

$log_dir = "/logs";   # Relative logs folder

$site_control = "a";  # Control action -- a=new domain, b=suspend domain, c=remove domain

# FTP Settings for virtual users #
$database_server = "";  # Server FQDN or IP
$database = "";         # Databse name
$database_user = "";    # Database user
$database_password = ""; # Database password
##### END VARS #####




#######################################################
###### BEGIN CODE -- DO NOT EDIT AFTER THIS LINE ######
#######################################################

##### SET INCLUDES #####
use DBI;
use DBD::mysql;
use warnings;
##### END INCLUDES #####


print "[A] Add a new domain\n[B] Suspend a domain\n[C] Remove a domain\n ";
do {
        print "\nEnter a choice [a]: ";
        $site_control = <STDIN>;
        chop $site_control;
}
until ($site_control eq 'a' || $site_control eq 'b' || $site_control eq 'c' || $site_control eq '');


do {
        print "Enter Domain Name: ";
        $domain = <STDIN>;
        chop $domain;
} 
until ($domain ne '');

do {
        print "Enter Username: ";
        $username = <STDIN>;
        chop $username;
}
until ($username ne '');


if ($site_control eq "a" || $site_control eq '') {

        $root_domain_path = "$root_site_path/$username/$domain";


        ### GET DESIRED OPTIONS ###
        do {
                print "Enable site logging? ([y]/n): ";
                $enable_site_logging = <STDIN>;
                chop $enable_site_logging;
        }
        until ($enable_site_logging eq 'y' || $enable_site_logging eq 'n' || $enable_site_logging eq '');

        do {
                print "Set default page to under construction? ([y]/n): ";
                $under_construction_default = <STDIN>;
                chop $under_construction_default;
        }
        until ($under_construction_default eq 'y' || $under_construction_default eq 'n' || $under_construction_default eq '');


        ### CREATE DEFAULT DIRECTORIES ###

        print "Creating directories... ";
        system ("mkdir $root_site_path/$username");
        system ("mkdir $root_domain_path");
        system ("mkdir $root_domain_path/web");
        system ("mkdir $root_domain_path/logs");
        system ("mkdir $root_domain_path/awstats");
        print "Done!\n";


        ### WRITE APACHE CONF FILES ###
        print "\n\nWriting HTTP Config files...\n";
        if ($write_to eq "vhost") {
                open(OUTFILE, ">$vhost_conf_dir/$domain.conf");
        }
        else {
                open(OUTFILE, ">>$httpd_conf_dir/$httpd_file");
        }
        
        print OUTFILE ("<VirtualHost westlabs.dmz.westlabs.biz>\n");
        print OUTFILE ("\tServerName www.$domain\n");
        print OUTFILE ("\tServerAlias $domain www.$domain\n");
        print OUTFILE ("\tServerAdmin webmaster\@$domain\n");
        print OUTFILE ("\tDocumentRoot $root_domain_path/web\n");
 
        ### ENABLE SITE LOGGING AND STATS PROCESSING ###
        if ($enable_site_logging eq "y" || $enable_site_logging eq "") {
                print "Setting up site logging and stats...";
                system ("mkdir $root_domain_path/logs");
                print OUTFILE ("\tCustomLog $root_domain_path/logs/web.log combined\n");

                system ("mkdir $root_domain_path/awstats");
                print "Done!\n";
        }


        print OUTFILE ("</VirtualHost>");
        close(OUTFILE);
        print "Writing HTTP Config files complete!\n\n";


        ### SET A DEFAULT UNDER CONSTRUCTION PAGE ###
        if ($under_construction_default eq "" || $under_construction_default eq "y") {
                print "Writing under construction data...";
                system ("cp /root/scripts/underconstruction.gif $root_domain_path/web/underconstruction.gif");

                open(OUTFILE, ">>$root_domain_path/web/index.html");
                        print OUTFILE ("<h1><center>$domain\n");
                        print OUTFILE ("<br><br>C O M I N G &nbsp\;&nbsp\; S O O N\n");
                        print OUTFILE ("<br><br><img src=underconstruction.gif>\n");
                        print OUTFILE ("<br><br>U N D E R &nbsp\;&nbsp\; C O N S T R U C T I O N</center></h1>\n");
                close(OUTFILE);
                print "Done!\n";
        }

        ###  SET PERMISSIONS ###
        print "Setting permissions... ";
        system ("chmod 755 $root_domain_path/web");
        system ("chown -R apache:apache $root_site_path/$username");
        print "Done!\n";


        ### SETUP FTP ACCESS ###
        do {
                print "Add FTP user? (y/[N]): ";
                $add_ftp_account = <STDIN>;
                chop $add_ftp_account;
        }
        until ($add_ftp_account eq 'y' || $add_ftp_account eq 'n' || $add_ftp_account eq '');

        if ($add_ftp_account eq "y") {
                print "FTP Password: ";
                $ftp_password = <STDIN>;
                chop $ftp_password;

                $connection = ConnectToMySql();

                # set the value of your SQL query
                $user_query = "INSERT INTO users (username, password, suser, sgroup, path) VALUES (?, PASSWORD(?), ?, ?, ?)\;";
                $auth_query = "INSERT INTO server_auth_users (userID, serverID) VALUES (LAST_INSERT_ID(), ?)\;";

                # prepare your statement for connecting to the database
                $user_statement = $connection->prepare($user_query);
                $auth_statement = $connection->prepare($auth_query);

                # execute your SQL statement
                $user_statement->execute($username, $ftp_password, 'apache', 'apache', $root_site_path."/".$username);
                $auth_statement->execute('1');
                ### END MYSQL FTP VHOST ###

                ### PRINT SUCCESS ###
                print "\n\n Site successfully added! \n\n";
        }

} ### END NEW SITE ###




# RESUME SITE
elsif ($site_control eq "b") {
        do {
                print "Are you sure? (y/[n]): ";
                $site_control_sure = <STDIN>;
                chop $site_control_sure;
        }
        until ($site_control_sure eq 'y' || $site_control_sure eq 'n');

        if ($site_control_sure eq "y") {
                print "Resuming $domain...\n\n";
                system ("mv -f $vhost_conf_dir/off/$domain.conf $vhost_conf_dir/");
                print "Done!\n";
        
                print "Enabling user account... ";
                system ("chmod 755 $root_site_path/$username");
                print "Done!\n";
                
                print "Enable complete!\n\n";
        }
        else {
                print "Canceled";
                exit();
        }
}



# SUSPEND SITE
elsif ($site_control eq "c") {
        do {
                print "Are you sure? (y/n): "; 
                $site_control_sure = <STDIN>;
                chop $site_control_sure;
        }
        until ($site_control_sure eq 'y' || $site_control_sure eq 'n');

        if ($site_control_sure eq "y") {
                print "Suspending $domain...\n\n";
                system ("mv $vhost_conf_dir/$domain.conf $vhost_conf_dir/off/");
                print "Done!\n";

                print "Disabling user account... ";
                system ("chmod 000 $root_site_path/$username/");
                print "Done!\n";

                print "Suspend complete!\n\n";
        }
        else {
                print "Canceled";
                exit();
        }
}



# REMOVE SITE
elsif ($site_control eq "d") {
        do {
                print "Are you sure? (y/n): ";
                $site_control_sure = <STDIN>;
                chop $site_control_sure;
        }
        until ($site_control_sure eq 'y' || $site_control_sure eq 'n');

        if ($site_control_sure eq "y") {
                print "Removing $domain...\n\n";
                print "Removing HTTPD Config...";
                system ("rm -f $vhost_conf_dir/$domain.conf");
                system ("rm -f $vhost_conf_dir/off/$domain.conf");
                print "Done!\n";
                print "Removing domain directories... ";
                system("rm -rf $root_site_path/$username/$public_html_dir/$domain");
                print "Done!\n";
                print "Removing site logs... ";
                system ("rm -f $root_site_path/$username/$log_dir/$domain.log");
                print "Done!\n\n";
                print "Remove complete!\n\n";
        }
        else {
                print "Canceled";
                exit();
        }
}


print "Restarting httpd...\n";
system ("service httpd restart");


exit();


#--- start sub-routine ------------------------------------------------
sub ConnectToMySql {
#----------------------------------------------------------------------



# assign the values to your connection variable
my $connectionInfo="dbi:mysql:$database;$database_server";


# the chomp() function will remove any newline character from the end of a string
chomp ($database, $database_server, $database_user, $database_password);

# make connection to database
my $l_connection = DBI->connect($connectionInfo,$database_user, $database_password);

# the value of this connection is returned by the sub-routine
return $l_connection;

}
