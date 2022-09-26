# Psorcast Hybrid Validation Code Tool
This repository contains code for adding hybrid validation codes to the Psorcast bridge project.

# Project setup

Before you can run the code through Android Studio, your environment must have the following environmental variables set first:

## Required
**BR_EMAIL** - Your email to sign into the Psorcast project

**BR_PW** - Your password to sign into the Psorcast project

**BR_ID** - The bridge project ID for either the Psorcast project

# Building and running the code

This project was created and maintained using Android Studio.  I imagine it could be imported into Eclipse as well, but I have not tested that setup.

To load the project, select "import existing gradle project" or simple "Open" in Android Studio.

To run the code, right click `HybridValidationCodeTool.java`, and click Run.

You can also build the JAR using gradle with the following commands:

`./gradlew jar`
This will build Psorcast/HybridStudyJava/ValidationCodeTool/build/libs/ValidationCodeTool.jar

# Troubleshooting Tool Errors
While running the JARS below, if you receive these error codes, this is most likely what they mean...

401 - There is most likely a problem with the bridge email and password you provided.  Make sure it is not a Synapse account, it needs to be a bridge account only, by creating a new user THROUGH the bridge API with email and password and NO synapse account linked.
403 - Your Bridge account does not have the researcher level permission to create a new external ID user on Bridge.

# Hybrid Validation Code Tool

This JAR can only be run with the proper arguments.  You must provide a researcher level bridge email, password, the bridge project ID, and the number of new ARC IDs to generate.

From the command line, the commands will generate 5 new ARC IDs:
cd *path_to_ValidationCodeTool.jar*
java -jar ValidationCodeTool.jar a@b.com password bridge-id 5

The number 5 at the end is how many validation codes to create.  In this instance, the output should look something like this, but with different, random, code values.
845399    E&mjbn1vJ
506358    iL1VU.YVS
349888    Rd.7c2hVN
643738    mSGz4Z!Hc
415060    &LJB4cvB4

It is a good idea to verify on Bridge Study Manager that the ARC IDs are created.

