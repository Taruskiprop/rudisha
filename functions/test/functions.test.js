const test = require('node:test');
const assert = require('node:assert/strict');
const {
  handleClaimCreated,
  handleClaimReviewed,
  notifyUser,
} = require('../notification_handlers');

function fakeTokenDatabase(tokens) {
  const deleted = [];
  return {
    deleted,
    database: {
      collection: (collectionName) => ({
        doc: (userId) => ({
          collection: (subcollectionName) => ({
            get: async () => {
              assert.equal(collectionName, 'users');
              assert.equal(subcollectionName, 'notificationTokens');
              return {
                docs: tokens.map((token, index) => ({
                  id: `token-${index}`,
                  ref: {
                    delete: async () => deleted.push(`token-${index}`),
                  },
                  data: () => token,
                })),
              };
            },
          }),
        }),
      }),
    },
  };
}

test('skips notification send if recipient has no device tokens', async () => {
  const {database} = fakeTokenDatabase([]);
  let sendCalled = false;
  const sent = await notifyUser({
    database,
    messaging: {
      sendEach: async () => {
        sendCalled = true;
      },
    },
    userId: 'owner',
    title: 'New claim',
    body: 'A claim arrived.',
    route: '/claims',
  });
  assert.equal(sent, 0);
  assert.equal(sendCalled, false);
});

test('sends web messages with the route link and removes invalid tokens', async () => {
  const {database, deleted} = fakeTokenDatabase([
    {
      token: 'valid-registration-token-123456',
      platform: 'web',
      webLink: 'https://polyfind.example',
    },
    {
      token: 'expired-registration-token-123456',
      platform: 'android',
      webLink: '',
    },
  ]);
  let sentMessages;

  const sent = await notifyUser({
    database,
    messaging: {
      sendEach: async (messages) => {
        sentMessages = messages;
        return {
          successCount: 1,
          responses: [
            {success: true},
            {
              success: false,
              error: {code: 'messaging/registration-token-not-registered'},
            },
          ],
        };
      },
    },
    userId: 'owner',
    title: 'New claim',
    body: 'A claim arrived.',
    route: '/claims',
    data: {claimId: 'item-owner'},
  });

  assert.equal(sent, 1);
  assert.equal(sentMessages.length, 2);
  assert.equal(sentMessages[0].webpush.fcmOptions.link, 'https://polyfind.example/#/claims');
  assert.equal(sentMessages[0].data.claimId, 'item-owner');
  assert.deepEqual(deleted, ['token-1']);
});

test('notifies the owner of the item attached to a new claim', async () => {
  const {database} = fakeTokenDatabase([
    {token: 'owner-registration-token-123456', platform: 'android'},
  ]);
  const messaging = {
    sendEach: async (messages) => {
      assert.equal(messages[0].notification.title, 'New claim received');
      assert.equal(messages[0].data.route, '/claims');
      return {successCount: 1, responses: [{success: true}]};
    },
  };
  const claimDatabase = {
    collection: (name) => ({
      doc: (id) => ({
        get: async () => {
          assert.equal(name, 'items');
          assert.equal(id, 'item-1');
          return {
            exists: true,
            data: () => ({postedBy: 'owner', title: 'Backpack'}),
          };
        },
        collection: () => ({
          get: async () => ({
            docs: [{
              id: 'token-1',
              ref: {delete: async () => {}},
              data: () => ({
                token: 'owner-registration-token-123456',
                platform: 'android',
              }),
            }],
          }),
        }),
      }),
    }),
  };

  const sent = await handleClaimCreated({
    database: claimDatabase,
    messaging,
    claim: {id: 'item-1_claimant', itemId: 'item-1'},
  });
  assert.equal(sent, 1);
});

test('sends review status to the claimant and routes back to the item', async () => {
  const {database} = fakeTokenDatabase([
    {token: 'claimant-registration-token-123456', platform: 'ios'},
  ]);
  const messaging = {
    sendEach: async (messages) => {
      assert.equal(messages[0].notification.title, 'Claim approved');
      assert.equal(messages[0].data.route, '/item/item-1');
      return {successCount: 1, responses: [{success: true}]};
    },
  };
  const databaseWithoutPendingClaims = {
    ...database,
    collection: (name) => ({
      doc: (id) => ({
        collection: (subcollectionName) => ({
          get: () => database.collection(name).doc(id)
            .collection(subcollectionName).get(),
        }),
      }),
      where: () => ({
        get: async () => ({docs: []}),
      }),
    }),
    batch: () => ({
      update() {},
      commit: async () => {},
    }),
  };

  const sent = await handleClaimReviewed({
    database: databaseWithoutPendingClaims,
    messaging,
    before: {status: 'pending'},
    after: {
      id: 'item-1_claimant',
      itemId: 'item-1',
      claimantId: 'claimant',
      status: 'approved',
    },
  });
  assert.equal(sent, 1);
});
