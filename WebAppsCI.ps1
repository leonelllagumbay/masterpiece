
# Prerequisite: NodeJS latest

# *Requirements:
# Angular SPA
# Typescript 2.9, stable release (required 3)
# Angular CLI
# Separation of ViewModel (UI logic) and business logic ( http, domain model, validation : built-in
# Dependency Injection ( Included in Angular setup )
# Unit test (headless browser)
# Bootstrap ( folder structure of css, images, etc ) -> assets/images, assets/scss/variables, assets/scss/mixins
# Multilingual support (ngx)
# Logging/Instrumentation ( maybe Azure Application Insights )
# TSLint, SCSS lint (stylelint)
# SCSS and JavaScript minification
# Protractor for end to end testing

# Get --project param for a project name or applicatio name
if ($args.Length -eq 0) {
    Write-Host -ForegroundColor Red `No project name specified. Example. PS> --project=ProjectName`
    exit
}
$appName = $null
foreach ($arg in $args) {
    $argParts = $arg.split('=')
    if ($argParts[0] -eq '--project') {
        $appName = $argParts[1]
    } else {
        Write-Host -ForegroundColor Red `No project name specified. Example. PS> --project=ProjectName`
        exit
    }
}

Write-Host -ForegroundColor Green `Generating project`

# Install angular CLI globally
Write-Host `Installing Angular CLI`
npm install -g @angular/cli 

 # Generate new app with the specified app name with scss compiler included
Write-Host `Creating new application`
ng new $appName --style=scss

cd $appName # go to the app directory

Write-Host `Generate test component`
cd src # navigate to src app directory
# Generate our first Angular component to test cli
ng generate component app/First 
cd ..

# Git is already setup here
git status

# Add remote repository
Write-Host `Add GIT remote repository` 
# git remote add repoAddress (Optional)

# Install Bootstrap resources
Write-Host `Installing Typescript`
npm install typescript --save # Get the latest stable version of typescript release
npm update typescript --save # Update typescript to the latest stable release (Optional)

Write-Host `Installing Tether`
npm install tether --save

Write-Host `Installing jQuery`
npm install jquery --save

Write-Host `Installing popper.js`
npm install popper.js --save

Write-Host `Installing Bootstrap`
npm install bootstrap --save

Write-Host `Installing ng-bootstrap`
npm install @ng-bootstrap/ng-bootstrap --save

# Add translation module
Write-Host `Installing translation module`
# Install ngx translation module, https://github.com/ngx-translate/core
npm install @ngx-translate/core --save
npm install @ngx-translate/http-loader --save

# Update Angular JSON file scripts and styles
$angularJson = 'angular.json'
$j = Get-Content $angularJson -raw | ConvertFrom-Json
$j.projects.$appName.architect.build.options.scripts = @(
    "node_modules/jquery/dist/jquery.js", 
    "node_modules/tether/dist/js/tether.js",
    "node_modules/popper.js/dist/umd/popper.js",
    "node_modules/bootstrap/dist/js/bootstrap.js"
)
$j.projects.$appName.architect.build.options.styles = @(
    "src/styles.scss", 
    "node_modules/bootstrap/scss/bootstrap.scss"
)
$j | ConvertTo-Json -Depth 20 | % {$_ -replace "                ", "  "} | Set-Content $angularJson

# Insert ng-bootstrap module in app.module.ts
$appModuleTsPath = 'src/app/app.module.ts'

# Process lines of text from file and assign result to $NewContent variable
$newContent = Get-Content -Path $appModuleTsPath |
    ForEach-Object {
        # If line matches string
        Write-Host $_
        if($_ -match 'imports:') {
            $_
            "    NgbModule.forRoot(),"
            "    HttpClientModule,"
            "    TranslateModule.forRoot({"
            "    loader: {"
            "      provide: TranslateLoader,"
            "        useFactory: HttpLoaderFactory,"
            "        deps: [HttpClient]"
            "      }"
            "    }),"
        } elseif ($_ -match "'@angular/core';") {
            $_
            "import { NgbModule } from '@ng-bootstrap/ng-bootstrap';"
            "import { HttpClientModule, HttpClient, HTTP_INTERCEPTORS } from '@angular/common/http';"
            "import { TranslateModule, TranslateLoader } from '@ngx-translate/core';"
            "import { TranslateHttpLoader } from '@ngx-translate/http-loader';"
        }  elseif ($_ -match "export class AppModule") {
            $_
            "export function HttpLoaderFactory(http: HttpClient) {"
            "    return new TranslateHttpLoader(http);"
            "}"
        }else {
            $_
        }
    }

# Write new content back to app module ts
$newContent | Out-File -FilePath $appModuleTsPath -Encoding Default -Force

# Insert test snippets to app.component.html to test bootstrap
$appComponentPath = 'src/app/app.component.html'
$newContent = Get-Content -Path $appComponentPath |
    ForEach-Object {
        # If line matches string
        Write-Host $_
        if($_ -match 'Welcome to') {
            $_
            "    <div class=""alert alert-primary"" role=""alert""> This is a primary alert</div>"
        } else {
            $_
        }
    }
$newContent | Out-File -FilePath $appComponentPath -Encoding Default -Force


# Install SCSS linting with stylelint, https://www.npmjs.com/package/stylelint
Write-Host `Install SCSS linting usng Stylelint`
npm install stylelint -g
npm install stylelint stylelint-scss  --save
npm install stylelint-config-recommended-scss --save

# Create Stylelint configuration file
 $Stylelintrc = ".stylelintrc"
 Add-Content -Path $Stylelintrc  -Value '{'
 Add-Content -Path $Stylelintrc  -Value '  "extends": "stylelint-config-recommended-scss",'
 Add-Content -Path $Stylelintrc  -Value '  "rules": {'
 Add-Content -Path $Stylelintrc  -Value '  }'
 Add-Content -Path $Stylelintrc  -Value '}'

# Insert run script in package.json
$appPackageJSONPath = 'package.json'
$newContent = Get-Content -Path $appPackageJSONPath |
    ForEach-Object {
        # If line matches string
        Write-Host $_
        if($_ -match '"lint": "ng lint",') {
            $_
            "    ""stylelint"": ""stylelint '**/*.scss'"","
            "    ""testwatchfalse"": ""ng test --watch=false"","
            "    ""buildprod"": ""ng build --prod"","
        } else {
            $_
        }
    }
$newContent | Out-File -FilePath $appPackageJSONPath -Encoding Default -Force

# Test stylelint
npm run stylelint
stylelint "**/*.scss"


# Generate our first build locally using development mode and production mode
ng build # Build development
ng build --prod # Build production


# Do initial JavaScript lint test
ng lint

# Kill processes that are using these ports 4202, 4203
$portOpen = netstat -ano | findstr 4202
$portOpen | ForEach-Object {
    $res = $_ -split '\s{1,}'
    Write-Host $res[5]
    if ($res[5]) {
        tskill $res[5]
    }
}
$portOpen = netstat -ano | findstr 4203
$portOpen | ForEach-Object {
    $res = $_ -split '\s{1,}'
    Write-Host $res[5]
    if ($res[5]) {
        tskill $res[5]
    }
}


# Do initial end-to-end test
ng e2e --port=4203 # Using protractor

# Do initial unit test
ng test --watch=false # pre test unit testing and exit after

# Serve the App
ng serve --port=4202 --open

exit