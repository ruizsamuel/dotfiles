# Configuración local de Samuel Ruiz
# Este archivo NO es trackeado por git - contiene información personal

{
  # Usuario y home directory
  username = "samuel";
  homeDirectory = "/home/samuel";
  stateVersion = "25.05";

  # Configuración de Git
  git = {
    userName = "Samuel Ruiz";
    userEmail = "samue@ruizsamuel.es";
    
    # Configuración de firma GPG
    signing = {
      enable = true;
      key = "6B50E0FDEA729EB7";
    };
  };
}
