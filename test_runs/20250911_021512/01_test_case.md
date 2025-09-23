# Kind: test_case
# Prompt

Create test cases for 2FA login (valid, expired, wrong code, rate limit)

# Response


---- Response (45941 ms) ----
Title:

Description:

Steps:

1. Test case 1: Valid 2FA code
   - Precondition: User has a valid 2FA setup and a working phone number.
   - Steps:
     1. The user attempts to log in with the correct 2FA code.
     2. Verify that the login is successful.

2. Test case 2: Expired 2FA code
   - Precondition: User has an expired 2FA setup and a working phone number.
   - Steps:
     1. The user attempts to log in with the expired 2FA code.
     2. Verify that the login fails.

3. Test case 3: Wrong 2FA code
   - Precondition: User has a valid 2FA setup but enters an incorrect code.
   - Steps:
     1. The user attempts to log in with the wrong 2FA code.
     2. Verify that the login fails.

4. Test case 4: Rate limit exceeded
   - Precondition: User is attempting to log in multiple times within a short period.
   - Steps:
     1. The user attempts to log in multiple times within a short period.
     2. Verify that the login is blocked due to rate limiting.

5. Test case 5: Missing 2FA setup
   - Precondition: User does not have a 2FA setup configured.
   - Steps:
     1. The user attempts to log in without a 2FA setup.
     2. Verify that the login fails and prompts the user to set up 2FA.

