#
# This implementation meets almost all cis hardening recommandation
#

# General Configuration
install
text
skipx
keyboard us
rootpw abc123
lang en_US.UTF-8
timezone Europe/Paris
network --onboot yes --device eth0 --bootproto dhcp --noipv6 
firstboot --disabled

# Storage partitioning and formatting is below. We use LVM here.
clearpart --all
zerombr
part /boot --fstype ext4 --size=250
part swap --size=1024
part pv.01 --size=1 --grow
volgroup vg_root pv.01
logvol / --vgname vg_root --name root --fstype=ext4 --size=10240
logvol /tmp --vgname vg_root --name tmp --size=500 --fsoptions="nodev,nosuid,noexec"
logvol /var --vgname vg_root --name var --size=500
logvol /var/log --vgname vg_root --name log --size=1024
logvol /var/log/audit --vgname vg_root --name audit --size=1024
logvol /home --vgname vg_root --name home --size=1024 --grow --fsoptions="nodev"
bootloader --location=mbr --driveorder=vda --append="selinux=1 audit=1"
reboot

%packages --resolvedeps --excludedocs --nobase
@core
-setroubleshoot            
-mcstrans                  
-telnet-server             
-telnet                    
-rsh-server                
-rsh                       
-ypbind                    
-ypserv                    
-tftp                      
-tftp-server               
-talk-server               
-xinetd                    
-@"X Window System"        
-dhcp                      

%post --log=/root/postinstall.log

# selinux, root password, iptables and the authentication mechanism.
echo "SELINUX=enforcing" > /etc/selinux/config
echo "SELINUXTYPE=targeted" >> /etc/selinux/config
echo "umask 027" >> /etc/sysconfig/init
echo "id:3:initdefault" >> /etc/inittab

chown root:root /etc/grub.conf
chmod og-rwx /etc/grub.conf

# extra packages and update
echo "nameserver  8.8.8.8" >> /etc/resolv.conf

echo '* Updating packages.'
yum update -y
echo '* Installing extra packages.'
yum install -y pciutils
yum install -y wget
yum install -y numactl
yum install -y vim
yum install -y ntp
yum install -y telnet
yum install -y java 
yum install -y curl 
yum install -y postfix                    
yum install -y rsyslog             
yum install -y cronie-anacron
yum install -y pam_passwdqc 
yum install -y aide

# aide configuration
/usr/sbin/aide --init -B 'database_out=file:/var/lib/aide/aide.db.gz'
echo "0 5 * * * /usr/sbin/aide --check" >> /etc/crontab
crontab -u root /etc/crontab

# audit configuration
cat << 'EOF' >> /etc/audit/audit.rules
# Events That Modify Date and Time Information 
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change
# Events That Modify User/Group Information
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
# Events That Modify the System's Network Environment 
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
# Events That Modify the System's Mandatory Access Controls
-w /etc/selinux/ -p wa -k MAC-policy
# Collect Login and Logout Events 
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
# Collect Session Initiation Information
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
# Collect Discretionary Access Control Permission Modification Events 
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=500 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=500 -F auid!=4294967295 -k perm_mod
# Collect Unsuccessful Unauthorized Access Attempts to Files
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access
# Collect Successful File System Mounts 
-a always,exit -F arch=b64 -S mount -F auid>=500 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=500 -F auid!=4294967295 -k mounts
# Collect File Deletion Events by User
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete
# Collect Changes to System Administration Scope 
-w /etc/sudoers -p wa -k scope
# Collect System Administrator Actions
-w /var/log/sudo.log -p wa -k actions
# Collect Kernel Module Loading and Unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules
EOF

echo -e "\n# Collect Use of Privileged Commands" >> /etc/audit/audit.rules
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f |  \
        awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged" }' >> /etc/audit/audit.rules

echo -e "\n# Make the Audit Configuration Immutable"
echo "-e 2" >> /etc/audit/audit.rules


# sysctl configuration
cat << 'EOF' > /etc/sysctl.conf
kernel.exec-shield = 1                                  
kernel.randomize_va_space = 2                           
net.ipv4.ip_forward = 0                                 
net.ipv4.tcp_syncookies = 1                             
net.ipv4.conf.default.rp_filter = 1                     
net.ipv4.conf.default.log_martians = 1                  
net.ipv4.conf.default.send_redirects = 0                
net.ipv4.conf.default.secure_redirects = 0              
net.ipv4.conf.default.accept_redirects = 0              
net.ipv4.conf.default.accept_source_route = 0           
net.ipv4.conf.all.send_redirects = 0                    
net.ipv4.conf.all.accept_redirects = 0                  
net.ipv4.conf.all.secure_redirects = 0                  
net.ipv4.conf.all.accept_source_route = 0               
net.ipv4.conf.all.log_martians = 1                      
net.ipv4.conf.all.rp_filter = 1                         
net.ipv4.icmp_echo_ignore_broadcasts = 1                
net.ipv4.icmp_ignore_bogus_error_responses = 1          
EOF

# pam configuration
sed -i 's/^#\(auth.*required.*pam_wheel.so.*\)$/\1/' /etc/pam.d/su
sed -i 's/^\(password.*sufficient.*pam_unix.so.*\)$/\1 remember=5/' /etc/pam.d/system-auth
sed -i -e '/pam_cracklib.so/{:a;n;/^$/!ba;i\password    requisite     pam_passwdqc.so min=disabled,disabled,16,12,8' -e '}' /etc/pam.d/system-auth
sed -i 's/password.+requisite.+pam_cracklib.so/password required pam_cracklib.so try_first_pass retry=3 minlen=14,dcredit=-1,ucredit=-1,ocredit=-1 lcredit=-1/' /etc/pam.d/system-auth


# ssh configuration and banners
sed -i 's/^#X11Forwarding no$/X11Forwarding no/' /etc/ssh/sshd_config
sed -i '/^X11Forwarding yes$/d' /etc/ssh/sshd_config
sed -i 's/^.*MaxAuthTries.*$/MaxAuthTries 4/' /etc/ssh/sshd_config
sed -i 's/^.*ClientAliveCountMax.*$/ClientAliveCountMax 0/' /etc/ssh/sshd_config
sed -i 's/^.*ClientAliveInterval.*$/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/^#Banner.*$/Banner \/etc\/ssh\/banner/' /etc/ssh/sshd_config

echo "Unauthorized access is prohibited." > /etc/ssh/banner
echo "Ciphers aes128-ctr,aes192-ctr,aes256-ctr" >> /etc/ssh/sshd_config 

echo "Authorized users only. All activity are monitored and reported." > /etc/motd
echo "Authorized users only. All activity are monitored and reported." > /etc/issue
echo "Authorized users only. All activity are monitored and reported." > /etc/issue.net

# services and others
echo "install dccp /bin/false" > /etc/modprobe.d/dccp.conf
echo "install sctp /bin/false" > /etc/modprobe.d/sctp.conf
echo "install rds /bin/false" > /etc/modprobe.d/rds.conf
echo "install tipc /bin/false" > /etc/modprobe.d/tipc.con

chkconfig ntpd on
chkconfig crond on
chkconfig auditd on
chkconfig postfix on
chkconfig ip6tables off
chkconfig iptables on
chkconfig cups off
chkconfig syslog off 
chkconfig avahi-daemon off

# directory and files access
chmod -R go-w /lib/ /lib64/
chmod -R go-w /usr/lib/ /usr/lib64/
/bin/bash: qa: command not found
chmod -R go-w /usr/local/bin/ /usr/local/sbin/

%end
