#cloud-config
hostname: ${hostname}
fqdn: ${fqdn}

# User configuration
users:
  - name: ${username}
    groups:
%{ for group in sudo_groups ~}
      - ${group}
%{ endfor ~}
    shell: ${user_shell}
%{ if length(ssh_keys) > 0 ~}
    ssh_authorized_keys:
%{ for key in ssh_keys ~}
      - ${key}
%{ endfor ~}
%{ endif ~}
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: ${lock_passwd}

%{ if password != "" ~}
chpasswd:
  list: |
    ${username}:${password}
  expire: false

ssh_pwauth: true
%{ endif ~}

disable_root: true

# Timezone
timezone: ${timezone}

%{ if length(packages) > 0 ~}
# Package installation
packages:
%{ for package in packages ~}
  - ${package}
%{ endfor ~}

%{ endif ~}
# System configuration
runcmd:
%{ for cmd in runcmd ~}
  - ${cmd}
%{ endfor ~}

%{ if length(write_files) > 0 ~}
# Custom files
write_files:
%{ for wf in write_files ~}
  - path: ${wf.path}
    content: ${jsonencode(wf.content)}
    owner: ${wf.owner}
    permissions: '${wf.permissions}'
%{ endfor ~}

%{ endif ~}
# Final message
final_message: |
  Cloud-init has finished configuring ${hostname}
  System is ready for use
