# Database connectivity tools for Wine applications
{ pkgs }:

{
  odbc-setup = pkgs.writeShellScriptBin "setup-odbc" ''
    echo "=== ODBC Setup for Wine ==="
    
    if [ -z "$WINEPREFIX" ]; then
        echo "Error: WINEPREFIX not set. Run from application launcher."
        exit 1
    fi
    
    echo "Configuring ODBC drivers via registry..."
    
    # Configure SQL Server driver
    wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "Driver" /t REG_SZ /d "sqlsrv32.dll" /f
    wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "Setup" /t REG_SZ /d "sqlsrv32.dll" /f
    wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "APILevel" /t REG_SZ /d "2" /f
    wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "ConnectFunctions" /t REG_SZ /d "YYY" /f
    wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "DriverODBCVer" /t REG_SZ /d "03.50" /f
    
    echo "✓ ODBC configuration completed"
  '';
  
  db-auth-setup = pkgs.writeShellScriptBin "setup-db-auth" ''
    echo "=== Database Authentication Setup ==="
    
    if [ -z "$WINEPREFIX" ]; then
        echo "Error: WINEPREFIX not set. Run from application launcher."
        exit 1
    fi
    
    echo "Choose authentication method:"
    echo "1. SQL Server Authentication (recommended for Wine)"
    echo "2. Windows Authentication (limited Wine support)"
    read -p "Select (1-2): " choice
    
    case "$choice" in
        1)
            read -p "Server name/IP: " server
            read -p "Database name: " database
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            
            # Create ODBC data source
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Driver" /t REG_SZ /d "SQL Server" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Server" /t REG_SZ /d "$server" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Database" /t REG_SZ /d "$database" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "UID" /t REG_SZ /d "$username" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "PWD" /t REG_SZ /d "$password" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Trusted_Connection" /t REG_SZ /d "No" /f
            
            echo "✓ SQL Server authentication configured"
            ;;
        2)
            read -p "Server name/IP: " server
            read -p "Database name: " database
            
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Driver" /t REG_SZ /d "SQL Server" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Server" /t REG_SZ /d "$server" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Database" /t REG_SZ /d "$database" /f
            wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_DB" /v "Trusted_Connection" /t REG_SZ /d "Yes" /f
            
            echo "✓ Windows authentication configured (may not work in Wine)"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo "Database authentication setup completed"
  '';
}
