#Pour l'initiation du whatif
[CmdletBinding(SupportsShouldProcess=$true)]
param (
    $Action,
    $CsvPath = "./compte.csv"
)

#Préparation du dossier de Log
$log = "C:\log"
if (!(Test-Path $log)) { New-Item -Path $log -ItemType Directory }
$logFile = "$log\log.log"

#Creation du dossier C:\Archives 
if (!(Test-Path "C:\Archives")) {
    New-Item -Path "C:\Archives" -ItemType Directory
}

#Importation des données depuis le fichier CSV 
$utilisateurs = Import-Csv -Path $CsvPath
#Préparation du mot de passe par défaut qui va être chiffré par la suite
$passwd = ConvertTo-SecureString "LucartR405" -AsPlainText -Force

#Ces lignes ajoutent la date, l'heure et le message dans le fichier de log
filter Write-Log {
    $date = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    Add-Content -Path $logFile -Value "$date - $_"
}

#Partie Creation
if ($Action -eq "Create") {
    #Boucle qui permet de lire chaque ligne du fichier CSV
    foreach ($user in $utilisateurs) {
        #Permet de définir l'OU de l'utilisateur (définit dans le fichier CSV)
        $cibleOU = "OU=$($user.OU),OU=Entreprise,DC=rt,DC=local"
        #Permet de vérifier si l'utilisateur existe déjà (basé sur le SamAccountName / Login)
        if (Get-ADUser -Filter "SamAccountName -eq '$($user.Login)'") {
            #Message d'avertissement en jaune si le compte existe déjà
            Write-Host "L'utilisateur $($user.Login) est deja cree." -ForegroundColor Yellow
            #Ecrit le message dans le fichier de log
            "L'utilisateur $($user.Login) est deja cree." | Write-Log
        }
        else {
            #Vérifie si le mode -WhatIf est activé et demande confirmation avant de créer l'utilisateur
            if ($PSCmdlet.ShouldProcess($user.Login, "CreationAD")) {
                #Création de l'utilisateur avec les informations importantes à sa création
                New-ADUser -Name "$($user.Prenom) $($user.Nom)" `
                        -GivenName $user.Prenom `
                        -Surname $user.Nom `
                        -SamAccountName $user.Login `
                        -Path $cibleOU `
                        -AccountPassword $passwd `
                        -ChangePasswordAtLogon $true `
                        -Enabled $true
                #Message qui s'affiche en vert lorsque l'utilisateur est créé
                Write-Host "Utilisateur $($user.Login) cree dans l'OU $($user.OU)." -ForegroundColor Green
                "Creation reussie pour $($user.Login)" | Write-Log
            }
        }
    }

    foreach ($user in $utilisateurs) {
        #Définition du chemin local pour la création du dossier de l'utilisateur
        $CheminUser = "C:\UsersData\$($user.Login)"
        #Permet de vérifier si le dossier existe déjà
        if (Test-Path $CheminUser) {
            Write-Host "Le dossier $CheminUser existe deja sur le disque." -ForegroundColor Yellow
            "Le dossier $CheminUser existe deja sur le disque." | Write-Log
        }
        else{ 
            if ($PSCmdlet.ShouldProcess($user.Login, "CreationDossier")) {
                #Création du répertoire de l'utilisateur
                New-Item -Path $CheminUser -ItemType Directory -Force
                #On attribue les droits de l'utilisateur avec le contrôle total "F" sur les dossiers et fichiers 
                icacls $CheminUser /grant "$($user.Login):(OI)(CI)F"
                "Dossier personnel cree pour $($user.Login)" | Write-Log
                Write-Host "Dossier cree : $CheminUser" -ForegroundColor Green
            }
        }
    }
}


#Partie Suppression
if ($Action -eq "Delete") {
    foreach ($user in $utilisateurs) {
        if ($PSCmdlet.ShouldProcess($user.Login, "Suppression/Archivage")) {
            #On vérifie si l'utilisateur existe
            if (Get-ADUser -Filter "SamAccountName -eq $($user.Login)") {
                #On supprime l'utilisateur sans avoir besoin de confirmer la suppression "$false"
                Remove-ADUser -Identity $user.Login -Confirm:$false
                Write-Host "L'utilisateur $($user.Login) a ete supprime avec succes de l'AD." -ForegroundColor Green
                "Suppression AD pour $($user.Login)" | Write-Log
            }
            else{
                #On affiche un message d'erreur si l'utilisateur n'existe pas
                Write-Host "Erreur : L'utilisateur $($user.Login) n'existe pas dans l'Active Directory." -ForegroundColor Red
            }

            $CheminUser = "C:\UsersData\$($user.Login)"
            # Vérifier si le dossier de l'utilisateur existe
            if (Test-Path $CheminUser) {
                $dateZ = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
                #Creation de l'archive ZIP
                Compress-Archive -Path $CheminUser -DestinationPath "C:\Archives\$($user.Login)_$dateZ.zip"
                # Supprime le dossier original après l'archivage
                Remove-Item -Path $CheminUser -Recurse -Force
                "Archivage et suppression dossier pour $($user.Login)" | Write-Log
            }
            else {
                Write-Host "Impossible d'archiver le dossier de $($user.Login)." -ForegroundColor Red
            }
            Write-Host "Utilisateur $($user.Login) supprime et archive." -ForegroundColor green
        }
    }
}