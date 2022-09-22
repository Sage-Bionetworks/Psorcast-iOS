package org.sagebionetworks.psorcast.bridgetools;

import com.google.common.annotations.VisibleForTesting;
import com.google.common.collect.ImmutableMap;
import com.google.common.collect.Lists;

import org.sagebionetworks.bridge.rest.ClientManager;
import org.sagebionetworks.bridge.rest.api.AdherenceRecordsApi;
import org.sagebionetworks.bridge.rest.api.AssessmentsApi;
import org.sagebionetworks.bridge.rest.api.AuthenticationApi;
import org.sagebionetworks.bridge.rest.api.ForResearchersApi;
import org.sagebionetworks.bridge.rest.api.ParticipantReportsApi;
import org.sagebionetworks.bridge.rest.api.ParticipantsApi;
import org.sagebionetworks.bridge.rest.api.SchedulesV2Api;
import org.sagebionetworks.bridge.rest.api.StudyActivityEventsApi;
import org.sagebionetworks.bridge.rest.model.ClientInfo;
import org.sagebionetworks.bridge.rest.model.SharingScope;
import org.sagebionetworks.bridge.rest.model.SignIn;
import org.sagebionetworks.bridge.rest.model.SignUp;
import org.sagebionetworks.bridge.rest.model.StudyParticipant;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class BridgeJavaSdkUtil {
    // Bridge Authentication vars
    public static String BRIDGE_EMAIL = System.getenv("BR_EMAIL");
    public static String BRIDGE_PW = System.getenv("BR_PW");
    private static String BRIDGE_ID = System.getenv("BR_ID");

    // Study IDs
    protected static final String HYBRID_VALIDATION_STUDY_ID = "hybrid_validation_study";

    // User attribute keys
    protected static final String ATTRIBUTE_VALUE_CONSUMED = "consumed";
    protected static final String ATTRIBUTE_VALUE_FALSE = "false";
    protected static final String ATTRIBUTE_VALUE_TRUE = "true";

    // Password Requirements
    protected static final String CODE_SUFFIX = "Hybrid!";

    // Flag migration accounts as test_users so that we can filter them out in Bridge or Synapse
    public static String TEST_USER_DATA_GROUP = "test_user";

    // Maximum character count for user attributes
    private static final int ATTRIBUTE_LENGTH_MAX = 255;

    private static ForResearchersApi researcherApi;
    private static ParticipantReportsApi reportsApi;
    private static ParticipantsApi participantsApi;
    private static StudyActivityEventsApi activityEventsApi;
    private static AssessmentsApi assessmentsApi;
    private static SchedulesV2Api scheduleApi;
    private static AdherenceRecordsApi adherenceRecordsApi;

    @VisibleForTesting
    protected static void mockInitialize(ForResearchersApi mockResearcherApi,
                                         ParticipantReportsApi mockReportsApi,
                                         ParticipantsApi mockParticipantsApi,
                                         StudyActivityEventsApi mockActivityEventsApi,
                                         AssessmentsApi mockAssessmentsApi,
                                         SchedulesV2Api mockScheduleApi,
                                         AdherenceRecordsApi mockAdherenceApi) {
        researcherApi = mockResearcherApi;
        reportsApi = mockReportsApi;
        participantsApi = mockParticipantsApi;
        activityEventsApi = mockActivityEventsApi;
        assessmentsApi = mockAssessmentsApi;
        scheduleApi = mockScheduleApi;
        adherenceRecordsApi = mockAdherenceApi;
    }

    /**
     * Authenticates the admin user using the parameters provided instead of with env vars.
     * Must call this before any other functions in this class will succeed.
     * @param email account for accessing bridge
     * @param password for email account for accessing bridge
     * @param bridgeId bridge project identifier
     * @throws IOException if something went wrong with the network request
     */
    public static void initialize(String email, String password, String bridgeId) throws IOException {
        BRIDGE_EMAIL = email;
        BRIDGE_PW = password;
        BRIDGE_ID = bridgeId;

        initialize();
    }

    /**
     * Authenticates the admin user using the environmental vars for email/password.
     * Must call this before any other functions in this class will succeed.
     * @throws IOException if something went wrong with the network request
     */
    public static void initialize() throws IOException {

        ClientInfo clientInfo = new ClientInfo()
                .appName("PsorcastHybridValidationTool")
                .deviceName("Sage-Bionetworks Device")
                .appVersion(1);

        SignIn signIn = new SignIn()
                .appId(BRIDGE_ID)
                .email(BRIDGE_EMAIL)
                .password(BRIDGE_PW);

        ClientManager clientManager = new ClientManager.Builder()
                .withClientInfo(clientInfo)
                .withSignIn(signIn)
                .withAcceptLanguage(Lists.newArrayList("en")).build();

        AuthenticationApi authApi = clientManager.getClient(AuthenticationApi.class);
        researcherApi = clientManager.getClient(ForResearchersApi.class);
        reportsApi = clientManager.getClient(ParticipantReportsApi.class);
        participantsApi = clientManager.getClient(ParticipantsApi .class);
        activityEventsApi = clientManager.getClient(StudyActivityEventsApi.class);
        assessmentsApi = clientManager.getClient(AssessmentsApi.class);
        scheduleApi = clientManager.getClient(SchedulesV2Api.class);
        adherenceRecordsApi = clientManager.getClient(AdherenceRecordsApi.class);
    }

    public static String createParticipant(SignUp signUp) throws IOException {
        return researcherApi.createParticipant(signUp).execute().body().getIdentifier();
    }

    /**
     * Create a random hybrid validation code, in the form of an External ID account
     * @return a SignUp object that can be used to add a hybrid validation code to bridge.
     */
    protected static String createHybridValidationCode(String validationCode) throws IOException {

        // Validation codes should be flagged as a "test_user"
        List<String> dataGroups = new ArrayList<>();
        dataGroups.add(TEST_USER_DATA_GROUP);
        // They should also not share data with Synapse
        SharingScope sharingScope = SharingScope.NO_SHARING;

        Map<String, String> attributeMap = new HashMap<>();
        attributeMap.put(ATTRIBUTE_VALUE_CONSUMED, ATTRIBUTE_VALUE_FALSE);
        bridgifyAttributes(attributeMap);

        // To meet bridge password requirements, add uppercase letter, lowercase letter, and symbol
        String password = validationCode + CODE_SUFFIX;

        SignUp signUp = new SignUp()
                .externalIds(ImmutableMap.of(HYBRID_VALIDATION_STUDY_ID, validationCode))
                .password(password)
                .dataGroups(dataGroups)
                .sharingScope(sharingScope)
                .attributes(attributeMap);

        return createParticipant(signUp);
    }

    /**
     * Bridge requires attributes to be less than a certain length
     * This function truncates attributes that are too long so that they save to bridge.
     * @param attributes to make sure they will upload to bridge
     */
    protected static void bridgifyAttributes(Map<String, String> attributes) {
        for (String key: attributes.keySet()) {
            String val = attributes.get(key);
            attributes.put(key, val.substring(0, Math.min(val.length(), ATTRIBUTE_LENGTH_MAX)));
        }
    }
}
