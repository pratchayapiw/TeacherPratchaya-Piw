/* Teacher Pratchaya authentication using Supabase Auth v2 */
(function () {
  "use strict";

  var cfg = window.TP_SUPABASE_CONFIG;
  if (!cfg || !window.supabase || !window.supabase.createClient) {
    throw new Error("Supabase client/configuration is missing.");
  }

  var client = window.supabase.createClient(cfg.url, cfg.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: "pkce"
    }
  });

  var session = null;
  var listeners = [];

  client.auth.getSession().then(function (result) {
    session = result.data ? result.data.session : null;
  });

  client.auth.onAuthStateChange(function (event, nextSession) {
    session = nextSession || null;
    listeners.slice().forEach(function (fn) {
      try { fn(event, session); } catch (error) { console.error(error); }
    });
  });

  async function getSession() {
    var result = await client.auth.getSession();
    if (result.error) throw result.error;
    session = result.data.session || null;
    return session;
  }

  async function isAdmin() {
    if (!session) await getSession();
    if (!session) return false;

    var result = await client.rpc("hub_is_admin");
    if (result.error) throw result.error;
    return result.data === true;
  }

  async function signIn(email, password) {
    var result = await client.auth.signInWithPassword({
      email: String(email || "").trim().toLowerCase(),
      password: String(password || "")
    });

    if (result.error) throw result.error;
    session = result.data.session || null;

    if (!(await isAdmin())) {
      await client.auth.signOut();
      session = null;
      throw new Error("บัญชีนี้ยังไม่ได้รับสิทธิ์ผู้ดูแล Teacher Dashboard");
    }

    return result.data;
  }

  async function signOut() {
    var result = await client.auth.signOut();
    if (result.error) throw result.error;
    session = null;
  }

  async function sendPasswordReset(email) {
    var redirectTo = window.location.origin + window.location.pathname + "?reset=1";
    var result = await client.auth.resetPasswordForEmail(
      String(email || "").trim().toLowerCase(),
      { redirectTo: redirectTo }
    );

    if (result.error) throw result.error;
    return true;
  }

  async function updatePassword(password) {
    var result = await client.auth.updateUser({
      password: String(password || "")
    });

    if (result.error) throw result.error;
    return result.data;
  }

  function onAuthStateChange(callback) {
    if (typeof callback === "function") listeners.push(callback);
    return function () {
      listeners = listeners.filter(function (fn) { return fn !== callback; });
    };
  }

  window.TP_AUTH = {
    getSession: getSession,
    getAccessToken: function () {
      return session && session.access_token ? session.access_token : null;
    },
    isAdmin: isAdmin,
    signIn: signIn,
    signOut: signOut,
    sendPasswordReset: sendPasswordReset,
    updatePassword: updatePassword,
    onAuthStateChange: onAuthStateChange
  };
})();
