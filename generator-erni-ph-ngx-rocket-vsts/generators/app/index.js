
/**
 * TODO
 * npm link
 * npm install -g yo
 * npm install request
 * https://leonelllagumbay.visualstudio.com/
 */

var $ProjectName = 'Pepsi';

const util = require('util');
const exec = util.promisify(require('child_process').exec);
var child_process = require('child_process');
const path = require('path').join(require('os').homedir(), 'Desktop');
var filessystem = require('fs');

const Generator = require('yeoman-generator');

const Request = require("request");

var $UserParams = {};
var $Headers = {};


module.exports = class extends Generator {
	constructor(args, opts) {
		super(args, opts);
		
		this.options = {
			ProjectName: $ProjectName,
			Description: `Description for ${$ProjectName} project`,
			RepositoryName: `${$ProjectName}Repo`,
			BuildDefinitionName: `${$ProjectName} - CI`,
			ProcessType: "Agile",
			VSTSMasterAcct: "leonelllagumbay",
			UserEmail: "lale@erni.ph",
			PAT: "inlx73csceyuxivitd7a2r262vwx6swzltr2y4ei5kbbxdce6ukq",
			SourceControlType: "Git",
			NpmTaskId: "fe47e961-9fa8-4106-8639-368c022d43ad",
			RepositoryType: "TfsGit"
		}
		
  }

	
	addVSTSProject() {
    $UserParams = this.options;
		const vstsConnection = new VSTSProjectCreator();
		vstsConnection.CreateVSTSProject();
	}
};

class  VSTSProjectCreator {
  /**
   * Create VSTS Project and add build definition for Angular app
   */
	async CreateVSTSProject() {
		
    $Headers = this.GetVSTSRestHeaders();
    
    const $Fnd = await this.GetVSTSProjects();
    console.log('does find it', $Fnd);

    if ($Fnd) {
      this.CreateProjectBuildDefinition();
      console.log('Updating existing project build...');
    } else { // Create a new project
      // Project does not exist, create a new one
      const $ProcessId = await this.GetVSTSProcessId();
      console.log('Creating a project. Process id is', $ProcessId);
      if ($ProcessId) {
        const jsonBody = this.GetProjectJsonBody($ProcessId);
        await this.MakeVSTSProject(jsonBody);
        const _self = this;
        setTimeout(() => {
          _self.CreateProjectBuildDefinition();
          console.log('Creating a new project build...');
        }, 70000);
      } else {
          console.log("Process type is not defined");
          return 0;
      }
    }

  }

  GetVSTSProjects() {
    // Check if project already exists
    const url = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/_apis/projects`;
    const qs = {
      'api-version': '4.1'
    }

    const opts = {
			method: 'GET',
			headers: $Headers,
			url: url,
			qs: qs
    };

    const _self = this;
    return new Promise((resolve, reject) => {
      Request(opts, function (error, response, currentProjectbody) {
        const $CurrProjects = JSON.parse(currentProjectbody);
        if (error) throw new Error(error);
        let $Fnd = false;
        if ($CurrProjects && $CurrProjects.value) {
          $CurrProjects.value.map(element => {
            if (element.name === $UserParams.ProjectName) {
              $Fnd = true;
            }
          });
        }
        
        resolve($Fnd);
      });
    });
  }

  MakeVSTSProject(jsonBody) {
    const $Url = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/_apis/projects`;
    const qs = {
      'api-version': '4.1'
    }
    const opts = {
      method: 'POST',
      headers: $Headers,
      url: $Url,
      qs: qs,
      json: true,
      body: jsonBody
    }

    return new Promise((resolve, reject) => {
      Request(opts, function (error, response, body) {
        // const $ProjectCreationResult = JSON.parse(body);
        console.log('Project was created.', error, response, body);
        resolve(true);
      });
    });
  }
  
  GetVSTSProcessId() {
    const $ProcessesUri = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/_apis/process/processes`;
    const qs = {
      'api-version': '4.1'
    }
    
    const opts = {
      method: 'GET',
      headers: $Headers,
      url: $ProcessesUri,
      qs: qs
    }

    return new Promise((resolve, reject) => {
      Request(opts, function (error, response, body) {
        const $CurrProcesses = JSON.parse(body);
        let $ProcessId = "";
        if ($CurrProcesses && $CurrProcesses.value) {
          $CurrProcesses.value.map(element => {
            if (element.name === $UserParams.ProcessType) {
              $ProcessId = element.id
            }
          })
        }
        resolve($ProcessId);
      });
    });
  }

  GetProjectJsonBody($ProcessId) {
    return {
      name: $UserParams.ProjectName,
      description: $UserParams.Description,
      capabilities: {
        versioncontrol: {
          sourceControlType: $UserParams.SourceControlType
        },
        processTemplate: {
          templateTypeId: $ProcessId
        }
      }
    }
  }
	
	GetVSTSRestHeaders() {
		const $Token = $UserParams.PAT;
		const encodedPat = this.EncodePat($Token);
		const $Headers = {
			'Content-type': 'application/json',
			'Cache-control': 'no-cache',
			Authorization: `Basic ${encodedPat}`
		}
		return $Headers;
	}
	
	EncodePat(pat) {
	   var b = new Buffer(':' + pat);
	   var s = b.toString('base64');
	   return s;
  }
  
  async CreateProjectBuildDefinition() {
    const $remoteRepoUrl = await this.GetGitRemoteUrl();
    
    const $NpmTaskId = $UserParams.NpmTaskId;
    let $BuildDefinitionObject = {
      project: await this.GetProjectObject($UserParams, $Headers),
      queueStatus: 'enabled',
      type: 'build',
      path: '\\',
      name: $UserParams.BuildDefinitionName,
      drafts: [],
      authoredBy: {},
      quality: 'definition',
      processParameters: {},
      repository: await this.GetProjectRepositoryObject($remoteRepoUrl),
      jobAuthorizationScope: 'projectCollection',
      jobTimeoutInMinutes: 60,
      jobCancelTimeoutInMinutes: 5,
      _links: {
          self: {},
          web: {},
          editor: {},
          badge: {}
      },
      tags: [],
      properties: {},
      retentionRules: await this.GetRetentionRules(),
      variables: {
        'system.debug': {
          value: false,
          allowOverride: true
        }
      },
      triggers: [{
        triggerType: 'continuousIntegration',
        branchFilters: ['+refs/heads/master'],
        batchChanges: false,
        maxConcurrentBuildsPerBranch: 1,
        pollingInterval: 0
      }],
      options: await this.GetOptions(),
      queue: {
        _links: {
          self: {}
        },
        name: 'Hosted VS2017',
        pool: {
          id: 4,
          name: 'Hosted VS2017',
          isHosted: true
        }
      },
      process: {
        type: 1,
        phases: [{
          steps: this.GetStepNpmRun($NpmTaskId),
          name: 'Phase 1',
          refName: 'Phase_1',
          condition: 'succeeded()',
          target: {
            executionOptions: {
              type: 0
            },
            allowScriptsAuthAccessOption: false,
            type: 1
          },
          jobAuthorizationScope: 'projectCollection',
          jobCancelTimeoutInMinutes: 1
        }]
      }
    }

    const $BuildDefinitionUri = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/${$UserParams.ProjectName}/_apis/build/definitions`;
    const qs = {
      'api-version': '4.1'
    }

    const opts = {
			method: 'POST',
			headers: $Headers,
			url: $BuildDefinitionUri,
      qs: qs,
      json: true,
      body: $BuildDefinitionObject
    };

    const _self = this;

		Request(opts, function (error, response, body) {
      console.log('Build definition was successfully created!!!', body);
      _self.CreateAngularProject();
    });
  }

  GetProjectObject() {
  
    const $Url = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/_apis/projects/${$UserParams.ProjectName}`;
    const qs = {
      'api-version': '4.1'
    }
    const opts = {
      method: 'GET',
      headers: $Headers,
      url: $Url,
      qs: qs
    }

    return new Promise((resolve, reject) => {
      Request(opts, function (error, response, body) {
        if (error) reject(error);
        const $ProjectObject = JSON.parse(body);
        const val = {
          id: $ProjectObject.id,
          name: $ProjectObject.name,
          state: $ProjectObject.state,
          visibility: $ProjectObject.visibility
        }
        resolve(val);
      });
    })
    
  }

  GetProjectRepositoryObject($Url) {
    const _self = this;
    return new Promise((resolve, reject) => {
      resolve({
        properties: {
          cleanOptions: 0,
          labelSources: 0,
          labelSourcesFormat: '`$(build.buildNumber)`',
          reportBuildStatus: true,
          gitLfsSupport: false,
          skipSyncSource: false,
          checkoutNestedSubmodules: false,
          fetchDepth: 0
        },
        type: $UserParams.RepositoryType,
        name: $UserParams.ProjectName,
        url: $Url,
        defaultBranch: 'refs/heads/master',
        clean: false,
        checkoutSubmodules: false
      })
    })
    
  }

  GetGitRemoteUrl() {
    console.log('The project id is: ', $UserParams.ProjectName);
    
    const $Url = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/${$UserParams.ProjectName}/_apis/git/repositories`;
    const qs = {
      'api-version': '4.1'
    }
    const opts = {
      method: 'GET',
      headers: $Headers,
      url: $Url,
      qs: qs
    }

    return new Promise((resolve, reject) => {
      Request(opts, function (error, response, body) {
        if (error) reject(error);
        const $response = JSON.parse(body);
        let $remoteGitUrl = '';
        if ($response && $response.value) {
          $response.value.map(element => {
            $remoteGitUrl = element.remoteUrl
          });
        }
        resolve($remoteGitUrl);
      });
    })

  }

  GetRetentionRules() {
    const $Url = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/_apis/build/settings`;
    const qs = {
      'api-version': '4.1'
    }
    const opts = {
      method: 'GET',
      headers: $Headers,
      url: $Url,
      qs: qs
    }
    return new Promise((resolve, reject) => {
      Request(opts, function (error, response, body) {
        const $SettingsObject = JSON.parse(body);
        resolve($SettingsObject.maximumRetentionPolicy);
      });
    });
  }

  GetOptions() {

    let $OptionsArray = [];
    let $Url = `https://${$UserParams.VSTSMasterAcct}.visualstudio.com/${$UserParams.ProjectName}/_apis/build/options`; // ?api-version=4.1"
    const qs = {
      'api-version': '4.1'
    }
    const opts = {
      method: 'GET',
      headers: $Headers,
      url: $Url,
      qs: qs
    }
    return new Promise((resolve, reject) => {
      Request(opts, function (error, response, body) {
        const $OptionsObjectArray = JSON.parse(body);
        if ($OptionsObjectArray && $OptionsObjectArray.value) {
          $OptionsObjectArray.value.map(element => {
            $OptionsArray.push({
              enabled: false,
              definition: {
                  id: element.id
              },
              inputs: element.inputs
            });
          });
        }
        
        resolve($OptionsArray);
      });
    });
  }

  GetStepNpmRun($NpmTaskId) {
    return [{
      environment: {},
      enabled: true,
      continueOnError: false,
      alwaysRun: false,
      displayName: 'npm install typescript -g',
      timeoutInMinutes: 0,
      condition: 'succeeded()',
      task: {
        id: $NpmTaskId,
        versionSpec: '1.*',
        definitionType: 'task'
      },
      inputs: {
        command: 'custom',
        workingDir: '',
        verbose: false,
        customCommand: 'install typescript -g',
        customRegistry: 'useNpmrc',
        customFeed: '',
        customEndpoint: '',
        publishRegistry: 'useExternalRegistry',
        publishFeed: '',
        publishEndpoint: ''
      }
    }, {
      environment: {},
      enabled: true,
      continueOnError: false,
      alwaysRun: false,
      displayName: 'npm install -g @angular/cli',
      timeoutInMinutes: 0,
      condition: 'succeeded()',
      task: {
        id: $NpmTaskId,
        versionSpec: '1.*',
        definitionType: 'task'
      },
      inputs: {
        command: 'custom',
        workingDir: '',
        verbose: false,
        customCommand: 'install -g @angular/cli',
        customRegistry: 'useNpmrc',
        customFeed: '',
        customEndpoint: '',
        publishRegistry: 'useExternalRegistry',
        publishFeed: '',
        publishEndpoint: ''
      }
    }, {
      environment: {},
      enabled: true,
      continueOnError: false,
      alwaysRun: false,
      displayName: 'npm install -g generator-ngx-rocket',
      timeoutInMinutes: 0,
      condition: 'succeeded()',
      task: {
        id: $NpmTaskId,
        versionSpec: '1.*',
        definitionType: 'task'
      },
      inputs: {
        command: 'custom',
        workingDir: '',
        verbose: false,
        customCommand: 'install -g generator-ngx-rocket',
        customRegistry: 'useNpmrc',
        customFeed: '',
        customEndpoint: '',
        publishRegistry: 'useExternalRegistry',
        publishFeed: '',
        publishEndpoint: ''
      }
    }, {
      environment: {},
      enabled: true,
      continueOnError: false,
      alwaysRun: false,
      displayName: 'npm install',
      timeoutInMinutes: 0,
      condition: 'succeeded()',
      task: {
        id: $NpmTaskId,
        versionSpec: '1.*',
        definitionType: 'task'
      },
      inputs: {
        command: 'install',
        workingDir: '',
        verbose: false,
        customCommand: '',
        customRegistry: 'useNpmrc',
        customFeed: '',
        customEndpoint: '',
        publishRegistry: 'useExternalRegistry',
        publishFeed: '',
        publishEndpoint: ''
      }
    }, {
      environment: {},
      enabled: true,
      continueOnError: false,
      alwaysRun: false,
      displayName: 'npm run test:ci',
      timeoutInMinutes: 0,
      condition: 'succeeded()',
      task: {
        id: $NpmTaskId,
        versionSpec: '1.*',
        definitionType: 'task'
      },
      inputs: {
        command: 'custom',
        workingDir: '',
        verbose: false,
        customCommand: 'run test:ci',
        customRegistry: 'useNpmrc',
        customFeed: '',
        customEndpoint: '',
        publishRegistry: 'useExternalRegistry',
        publishFeed: '',
        publishEndpoint: ''
      }
    }, {
      environment: {},
      enabled: true,
      continueOnError: false,
      alwaysRun: false,
      displayName: 'npm run build',
      timeoutInMinutes: 0,
      condition: 'succeeded()',
      task: {
        id: $NpmTaskId,
        versionSpec: '1.*',
        definitionType: 'task'
      },
      inputs: {
        command: 'custom',
        workingDir: '',
        verbose: false,
        customCommand: 'run build',
        customRegistry: 'useNpmrc',
        customFeed: '',
        customEndpoint: '',
        publishRegistry: 'useExternalRegistry',
        publishFeed: '',
        publishEndpoint: ''
      }
    }]
  }

  async CreateAngularProject() {

    let $AppName = $UserParams.ProjectName
    console.log('Generating Angular project....', $AppName);


    // npm install -g typescript
    console.log('Installing typescript...');
    let out = await exec('npm install -g typescript');
    console.log(out);

    // npm install -g generator-ngx-rocket
    console.log('Installing generator-ngx-rocket...');
    out = await exec('npm install -g generator-ngx-rocket');
    console.log(out);

    // ngx new
    

    var dir = path + '\\' + $AppName;

    if (!filessystem.existsSync(dir)){
        filessystem.mkdirSync(dir);
    }
    console.log('Creating a new Angular app x...', dir);
    let $gitRemoteUrl = await this.GetGitRemoteUrl();
    child_process.exec(`start cmd.exe /c "cd /D ${dir} && ngx new && git remote add origin ${$gitRemoteUrl} && git add . && git commit -a -m \"My first commit\" && git push -u origin --all && npm start"`, () => {
      console.log('completed');
    });
    
    console.log('Remote URL', $gitRemoteUrl);
    // myExecSync('git remote add origin $gitRemoteUrl');

    //  Push changes to test VSTS project and build definition
    // git add .

    // git commit -a -m "My first commit"
    
    // git push -u origin --all

    // # Serve the App
    // npm start
    // myExecSync('npm start');
  }

  

}

// var env = Object.assign({}, process.env);

// var SEPARATOR = process.platform === "win32" ? ";" : ":",
// env = Object.assign({}, process.env);

// env.PATH = path.resolve("../../node_modules/.bin") + SEPARATOR + env.PATH;

// var execSync = require("child_process").execSync;

// var SEPARATOR = process.platform === "win32" ? ";" : ":",
//     env = Object.assign({}, process.env);

// env.PATH = path.resolve("../../node_modules/.bin") + SEPARATOR + env.PATH;

// function myExecSync(cmd) {
//     var output = execSync(cmd, {
//         cwd: process.cwd(),
//         env: env
//     });
//     console.log(output);
// }