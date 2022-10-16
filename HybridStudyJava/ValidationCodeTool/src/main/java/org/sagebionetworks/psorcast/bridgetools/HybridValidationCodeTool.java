package org.sagebionetworks.psorcast.bridgetools;

import java.io.IOException;
import java.nio.file.Paths;

public class HybridValidationCodeTool {

    private static final int VALIDATION_CODE_LENGTH = 8;

    public static void main(String[] args) throws IOException {
        if (args.length < 4) {
            throw new IllegalArgumentException("\nAt least 4 arguments must be provided," +
                    "java -jar progam_file.jar bridge_email bridge_pw bridge_project_id new_code_count\n" +
                    "Synapse-backed Bridge accounts are not supported at this time");
        }

        BridgeJavaSdkUtil.initialize(args[0], args[1], args[2]);
        int newValidationCodeCount = Integer.parseInt(args[3]);

        String csvFile = "Validation Code\n";

        for (int i = 0; i < newValidationCodeCount; i++) {
            String validationCode = PasswordGenerator.INSTANCE
                    .nextNumericOnlyPassword(VALIDATION_CODE_LENGTH);
            System.out.println("Adding " + validationCode + " to Bridge");
            BridgeJavaSdkUtil.createHybridValidationCode(validationCode);
            csvFile += validationCode + "\n";
        }

        PathsHelper.writeToFile(csvFile, Paths.get("validationCode.csv"));

        System.out.println("Successfully added " + newValidationCodeCount + " new codes to Bridge");
    }
}