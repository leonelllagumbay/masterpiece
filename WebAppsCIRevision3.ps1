$ProjectName = "GiantOregano"
$UserParams = @{
    ProjectName = $ProjectName
    Description = "Project " + $ProjectName
    RepositoryName = $ProjectName + " Repo"
    BuildDefinitionName = $ProjectName + " build definition"
    ProcessType = "Agile"
    VSTSMasterAcct = "leonelllagumbay"
    UserEmail = "lale@erni.ph"
    PAT = "inlx73csceyuxivitd7a2r262vwx6swzltr2y4ei5kbbxdce6ukq"
    SourceControlType = "Git"
    NpmTaskId = "fe47e961-9fa8-4106-8639-368c022d43ad"
    RepositoryType = "TfsGit"
}


function CreateVSTSProject() {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams
    )

    $Headers = GetVSTSRestHeaders -UserParams $UserParams
    Write-Host  ConvertTo-Json -Depth 70 -InputObject $Headers.Authorization
    
    try {
        # check if project already exists

        $ProjectUri = "https://" + $UserParams.VSTSMasterAcct + ".visualstudio.com/_apis/projects?api-version=4.1"
        
        $CurrProjects = Invoke-RestMethod -Uri $ProjectUri -Method Get -ContentType "application/json" -Headers $Headers
        
        $Fnd = $CurrProjects.value | Where-Object {$_.name -eq $UserParams.ProjectName}
        if (![string]::IsNullOrEmpty($Fnd)) {
            CreateProjectBuildDefinition -UserParams $UserParams -Headers $Headers
            CreateAngularProject -UserParams $UserParams -Headers $Headers
            Return "Existing project was successfully updated"
        } else {
            # Project does not exist, create new one
            $ProcessId = GetVSTSProcessId -UserParams $UserParams
            $ProjectJsonBody = GetProjectJsonBody -UserParams $UserParams -ProcessId $ProcessId
            $ProjectCreationResult = Invoke-RestMethod -Uri $ProjectUri -Method Post -ContentType "application/json" -Headers $Headers -Body $ProjectJsonBody
            $ProjectId = $UserParams.ProjectName
            
            Write-Host "Project was created. "
            Start-Sleep -s 60 # the repo may not yet available for some couple of seconds
            CreateProjectBuildDefinition -UserParams $UserParams -Headers $Headers
            CreateAngularProject -UserParams $UserParams -Headers $Headers
            Return "A new project was successfully created"
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Project Exists Error: " + $ErrorMessage + " iTEM : " + $FailedItem
        Write-Host $_.Exception
        Write-Host "If a new project is just created, the repo may not yet available for some couple of seconds."
        Write-Host "Please rerun the script to generate an Angular App"
    }

}

function GetVSTSProcessId {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams
    )

    $ProcessesUri = "https://" + $UserParams.VSTSMasterAcct + ".visualstudio.com/_apis/process/processes?api-version=4.1"
    $CurrProcesses = Invoke-RestMethod -Uri $ProcessesUri -Method Get -ContentType "application/json" -Headers $Headers

    $ProcessId = ""
    $CurrProcesses.value | ForEach-Object {
        if($_.name -match $UserParams.ProcessType) {
            $processId = $_.id
        }
    }

    if ($processId) {
        Return $processId
    } else {
        Write-Host "Process type is not defined"
        Exit
    }
}

function GetProjectJsonBody {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $ProcessId
    )
    # json body to create project
    $ObjectBody = @{
        name = $UserParams.ProjectName
        description = $UserParams.Description
        capabilities = @{
            versioncontrol = @{
                sourceControlType = $UserParams.SourceControlType
            }
            processTemplate = @{
                templateTypeId = $ProcessId
            }
        }
    }
    Return ConvertTo-Json -InputObject $ObjectBody -Depth 50
}

function GetVSTSRestHeaders {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams
    )

    $Token = $UserParams.PAT
    $Authentication = [Text.Encoding]::ASCII.GetBytes(":$Token")
    $Authentication = [System.Convert]::ToBase64String($Authentication)
    $Headers = @{
        Authorization = ("Basic {0}" -f $Authentication)
    }

    Return $Headers
}

function GetGitRemoteUrl {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $Headers
    )

    Write-Host "Project Id is"
    Write-Host $UserParams.ProjectName

    $remoteGitUrl = ''
    
    $Url = "https://" + $UserParams.VSTSMasterAcct + ".visualstudio.com/" + $UserParams.ProjectName + "/_apis/git/repositories?api-version=4.1"
    $response = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json" -Headers $Headers
    $response.value | ForEach-Object {
        $remoteGitUrl = $_.remoteUrl
    }
    Return $remoteGitUrl

}

function CreateProjectBuildDefinition {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $Headers
    )
    
    $NpmTaskId = $UserParams.NpmTaskId
    $BuildDefinitionObject = @{
        project=GetProjectObject -UserParams $UserParams -Headers $Headers
        queueStatus="enabled"
        type="build"
        path="\\"
        name=$UserParams.BuildDefinitionName
        drafts=@()
        authoredBy=@{}
        quality="definition"
        processParameters=@{}
        repository = GetProjectRepositoryObject -UserParams $UserParams -Headers $Headers
        jobAuthorizationScope="projectCollection"
        jobTimeoutInMinutes=60
        jobCancelTimeoutInMinutes=5
        _links=@{
            self=@{}
            web=@{}
            editor=@{}
            badge=@{}
        }
        tags=@()
        properties=@{}
        retentionRules=GetRetentionRules -UserParams $UserParams -Headers $Headers
        variables=@{
            "system.debug"=@{
                value=$false
                allowOverride=$true
            }
        }
        triggers=@(
            @{
                triggerType="continuousIntegration"
                branchFilters=@("+refs/heads/master")
                batchChanges=$false
                maxConcurrentBuildsPerBranch=1
                pollingInterval=0
            }
        )
        options=GetOptions -UserParams $UserParams -Headers $Headers
        queue=@{
		    _links=@{
			    self=@{}
		    }
		    name="Hosted VS2017"
		    pool=@{
			    id=4
			    name="Hosted VS2017"
			    isHosted=$true
		    }
	    }
        process=@{
           type=1
           phases=@(
              @{
                  steps=GetStepNpmRun -NpmTaskId $NpmTaskId
                  name="Phase 1"
                  refName="Phase_1"
                  condition="succeeded()"
                  target=@{
                    executionOptions=@{
                        type=0
                    }
                    allowScriptsAuthAccessOption=$false
                    type=1
                  }
                  jobAuthorizationScope="projectCollection"
                  jobCancelTimeoutInMinutes=1
              }
           )
        }      
    }

    $BuildDefinitionJson = ConvertTo-Json -Depth 70 -InputObject $BuildDefinitionObject
    $BuildDefinitionUri = "https://" + $UserParams.VSTSMasterAcct + ".visualstudio.com/" + $UserParams.ProjectName + "/_apis/build/definitions?api-version=4.1"
    Write-Host "aabbcc" + $Headers.Authorization
    $BuildDefinitionResult = Invoke-RestMethod -Uri $BuildDefinitionUri -Method Post -ContentType "application/json" -Headers $Headers -Body $BuildDefinitionJson

    Write-Host "abc"
    Write-Host "Build definition was successfully create"
    Write-Host ConvertTo-Json -Depth 70 -InputObject $BuildDefinitionResult
}

function GetProjectObject {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $Headers
    )
    
    $Url = "https://" + $UserParams.VSTSMasterAcct + ".visualstudio.com/_apis/projects/" + $UserParams.ProjectName + "?api-version=4.1"
    $ProjectObject = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json" -Headers $Headers
    Return @{
        id=$ProjectObject.id
        name=$ProjectObject.name
        state=$ProjectObject.state
        visibility=$ProjectObject.visibility
    }
}

function GetProjectRepositoryObject {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $Headers
    )

    Return @{
        properties=@{
            cleanOptions=0
            labelSources=0
            labelSourcesFormat="`$(build.buildNumber)"
            reportBuildStatus=$true
            gitLfsSupport=$false
            skipSyncSource=$false
            checkoutNestedSubmodules=$false
            fetchDepth=0
        }
        type=$UserParams.RepositoryType
        name=$UserParams.ProjectName
        url=GetGitRemoteUrl -UserParams $UserParams -Headers $Headers
        defaultBranch="refs/heads/master"
        clean=$false
        checkoutSubmodules=$false
    }
}

function GetRetentionRules {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $Headers
    )
    $Url = "https://" + $UserParams.VSTSMasterAcct + ".visualstudio.com/_apis/build/settings?api-version=4.1"
    $SettingsObject = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json" -Headers $Headers
    Return $SettingsObject.maximumRetentionPolicy
}


function GetOptions {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $Headers
    )

    $OptionsArray = @()
    $Url = "https://" + $UserParams.VSTSMasterAcct + ".visualstudio.com/" + $UserParams.ProjectName + "/_apis/build/options?api-version=4.1"
    $OptionsObjectArray = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json" -Headers $Headers
    $OptionsObjectArray.value | ForEach-Object {
        $OptionsArray += @{
            enabled=$false
            definition=@{
                id=$_.id
            }
            inputs=$_.inputs
        }
    }
  
    Return $OptionsArray
}


function GetStepNpmRun {
    Param(
        [Parameter(Mandatory = $true)]
        $NpmTaskId
    )

    Return @(
        @{
            environment=@{}
            enabled=$true
            continueOnError=$false
            alwaysRun=$false
            displayName="npm install typescript -g"
            timeoutInMinutes=0
            condition="succeeded()"
            task=@{
                id=$NpmTaskId
                versionSpec="1.*"
                definitionType="task"
            }
            inputs=@{
                command="custom"
                workingDir=""
                verbose=$false
                customCommand="install typescript -g"
                customRegistry="useNpmrc"
                customFeed=""
                customEndpoint=""
                publishRegistry="useExternalRegistry"
                publishFeed=""
                publishEndpoint=""
            }
        },
        @{
            environment=@{}
            enabled=$true
            continueOnError=$false
            alwaysRun=$false
            displayName="npm install -g @angular/cli"
            timeoutInMinutes=0
            condition="succeeded()"
            task=@{
                id=$NpmTaskId
                versionSpec="1.*"
                definitionType="task"
            }
            inputs=@{
                command="custom"
                workingDir=""
                verbose=$false
                customCommand="install -g @angular/cli"
                customRegistry="useNpmrc"
                customFeed=""
                customEndpoint=""
                publishRegistry="useExternalRegistry"
                publishFeed=""
                publishEndpoint=""
            }
        },
        @{
            environment=@{}
            enabled=$true
            continueOnError=$false
            alwaysRun=$false
            displayName="npm install -g generator-ngx-rocket"
            timeoutInMinutes=0
            condition="succeeded()"
            task=@{
                id=$NpmTaskId
                versionSpec="1.*"
                definitionType="task"
            }
            inputs=@{
                command="custom"
                workingDir=""
                verbose=$false
                customCommand="install -g generator-ngx-rocket"
                customRegistry="useNpmrc"
                customFeed=""
                customEndpoint=""
                publishRegistry="useExternalRegistry"
                publishFeed=""
                publishEndpoint=""
            }
        },
        @{
            environment=@{}
            enabled=$true
            continueOnError=$false
            alwaysRun=$false
            displayName="npm install"
            timeoutInMinutes=0
            condition="succeeded()"
            task=@{
                id=$NpmTaskId
                versionSpec="1.*"
                definitionType="task"
            }
            inputs=@{
                command="install"
                workingDir=""
                verbose=$false
                customCommand=""
                customRegistry="useNpmrc"
                customFeed=""
                customEndpoint=""
                publishRegistry="useExternalRegistry"
                publishFeed=""
                publishEndpoint=""
            }
        },
        @{
            environment=@{}
            enabled=$true
            continueOnError=$false
            alwaysRun=$false
            displayName="npm run test:ci"
            timeoutInMinutes=0
            condition="succeeded()"
            task=@{
                id=$NpmTaskId
                versionSpec="1.*"
                definitionType="task"
            }
            inputs=@{
                command="custom"
                workingDir=""
                verbose=$false
                customCommand="run test:ci"
                customRegistry="useNpmrc"
                customFeed=""
                customEndpoint=""
                publishRegistry="useExternalRegistry"
                publishFeed=""
                publishEndpoint=""
            }
        },
        @{
            environment=@{}
            enabled=$true
            continueOnError=$false
            alwaysRun=$false
            displayName="npm run build"
            timeoutInMinutes=0
            condition="succeeded()"
            task=@{
                id=$NpmTaskId
                versionSpec="1.*"
                definitionType="task"
            }
            inputs=@{
                command="custom"
                workingDir=""
                verbose=$false
                customCommand="run build"
                customRegistry="useNpmrc"
                customFeed=""
                customEndpoint=""
                publishRegistry="useExternalRegistry"
                publishFeed=""
                publishEndpoint=""
            }
        }
    )
}


function KillProcessWithPortNumber() {
    Param(
        [Parameter(Mandatory = $true)]
        $Port
    )
    $portOpen = netstat -ano | findstr $Port
    $portOpen | ForEach-Object {
        $res = $_ -split '\s{1,}'
        Write-Host $res[5]
        if ($res[5]) {
            tskill $res[5]
        }
    }
}

function CreateAngularProject {
    Param(
        [Parameter(Mandatory = $true)]
        $UserParams,
        [Parameter(Mandatory = $true)]
        $Headers
    )
    $AppName = $UserParams.ProjectName
    Write-Host -ForegroundColor Green `Generating Angular project...`

    # Install typescript
    Write-Host `Installing TypeScript...`
    npm install -g typescript

    # npm install -g generator-ngx-rocket
    Write-Host `Installing generator`
    npm install -g generator-ngx-rocket

    # New application
    ngx new

    # Git was already setup here
    git status

    # Add remote repository
    Write-Host `Add GIT remote repository` 
    $gitRemoteUrl = GetGitRemoteUrl -UserParams $UserParams -Headers $Headers
    git remote add origin $gitRemoteUrl


    # Push changes to test VSTS project and build definition
    git add .
    git commit -a -m "My first commit"
    git push -u origin --all

    # Kill processes that are using these ports 4202, 4203
    KillProcessWithPortNumber -Port 4200
    KillProcessWithPortNumber -Port 4201

    
    # Serve the App
    npm start
}

$result = CreateVSTSProject($UserParams);
Write-Host $result
