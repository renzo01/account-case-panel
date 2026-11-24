/**
 * Turns Salesforce error objects into a readable sentence.
 * Handles AuraHandledException, DML errors and generic JS errors.
 */
export function reduceErrors(errors) {
    const list = Array.isArray(errors) ? errors : [errors];

    const messages = list
        .filter(Boolean)
        .map((error) => {
            if (Array.isArray(error.body)) {
                return error.body.map((item) => item.message).join(', ');
            }
            if (error.body && typeof error.body.message === 'string') {
                return error.body.message;
            }
            if (typeof error.message === 'string') {
                return error.message;
            }
            return 'Something went wrong. Please try again.';
        })
        .filter((message) => message && message.trim().length > 0);

    return messages.length > 0
        ? messages.join(', ')
        : 'Something went wrong. Please try again.';
}
