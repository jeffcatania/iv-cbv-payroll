import { trackUserAction, fetchArgyleToken } from "@js/utilities/api.js"
import { getDocumentLocale } from "@js/utilities/getDocumentLocale.js"
import { ModalAdapter } from "./ModalAdapter.js"

export default class ArgyleModalAdapter extends ModalAdapter {
  async open() {
    const locale = getDocumentLocale()

    if (this.requestData) {
      await trackUserAction("ApplicantSelectedEmployerOrPlatformItem", {
        item_type: this.requestData.responseType,
        item_id: this.requestData.id,
        item_name: this.requestData.name,
        is_default_option: this.requestData.isDefaultOption,
        provider_name: this.requestData.providerName,
        locale,
      })

      const { user, isSandbox, flowId } = await fetchArgyleToken(this.requestData.id)
      return (this.modalSdk as Argyle)
        .create({
          userToken: user.user_token,
          flowId: flowId,
          items: [this.requestData.id],
          onAccountConnected: this.onSuccess.bind(this),
          onTokenExpired: this.onTokenExpired.bind(this),
          onAccountCreated: async (payload) => {
            await trackUserAction("ApplicantCreatedArgyleAccount", payload)
          },
          onAccountError: async (payload) => {
            await trackUserAction("ApplicantEncounteredArgyleAccountError", payload)
          },
          onAccountRemoved: async (payload) => {
            await trackUserAction("ApplicantRemovedArgyleAccount", payload)
          },
          onUIEvent: async (payload) => {
            await this.onUIEvent(payload)
          },
          onClose: this.onClose.bind(this),
          onError: this.onError.bind(this),
          sandbox: isSandbox,
        })
        .open()
    } else {
      // TODO this should throw an error, which should be caught by a document.onerror handler to show the user a crash message.
      await trackUserAction("ApplicantEncounteredModalAdapterError", {
        message: "Missing requestData from init() function",
      })
      this.onExit()
    }
  }

  async onError(err: LinkError) {
    await trackUserAction("ApplicantEncounteredArgyleError", err)
    this.onExit()
  }

  async onClose() {
    await trackUserAction("ApplicantClosedArgyleModal")
    await this.onExit()
  }

  async onUIEvent(payload: ArgyeUIEvent) {
    switch (payload.name) {
      case "search - opened":
        await trackUserAction("ApplicantViewedArgyleDefaultProviderSearch", payload)
        break
      case "login - opened":
        switch (payload.properties.errorCode) {
          case "auth_required":
            await trackUserAction("ApplicantEncounteredArgyleAuthRequiredLoginError", payload)
            break
          case "connection_unavailable":
            await trackUserAction(
              "ApplicantEncounteredArgyleConnectionUnavailableLoginError",
              payload
            )
            break
          case "expired_credentials":
            await trackUserAction("ApplicantEncounteredArgyleExpiredCredentialsLoginError", payload)
            break
          case "invalid_auth":
            await trackUserAction("ApplicantEncounteredArgyleInvalidAuthLoginError", payload)
            break
          case "invalid_credentials":
            await trackUserAction("ApplicantEncounteredArgyleInvalidCredentialsLoginError", payload)
            break
          case "mfa_cancelled_by_the_user":
            await trackUserAction("ApplicantEncounteredArgyleMfaCanceledLoginError", payload)
            break
          default:
            await trackUserAction("ApplicantViewedArgyleLoginPage", payload)
            break
        }
        break
      case "search - link item selected":
        await trackUserAction("ApplicantViewedArgyleProviderConfirmation", payload)
        break
      case "search - term updated":
        await trackUserAction("ApplicantUpdatedArgyleSearchTerm", {
          term: payload.properties.term,
          tab: payload.properties.tab,
          payload: payload,
        })
        break
      case "login - form submitted":
        await trackUserAction("ApplicantAttemptedArgyleLogin", payload)
        break
      case "mfa - opened":
        await trackUserAction("ApplicantAccessedArgyleModalMFAScreen", payload)
        break
      default:
        break
    }
  }

  async onSuccess(eventPayload: ArgyleAccountData) {
    await trackUserAction("ApplicantSucceededWithArgyleLogin", {
      account_id: eventPayload.accountId,
      argyle_user_id: eventPayload.userId,
      item_id: eventPayload.itemId,
      payload: eventPayload,
    })

    if (this.successCallback) {
      this.successCallback(eventPayload.accountId)
    }
  }

  async onTokenExpired(updateToken: Function) {
    await trackUserAction("ApplicantEncounteredArgyleTokenExpired")
    const { user } = await fetchArgyleToken()
    updateToken(user.user_token)
  }
}
