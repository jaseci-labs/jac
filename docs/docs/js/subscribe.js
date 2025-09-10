class SubscribeWidget {
  constructor() {
    this.form = document.getElementById("subscribeFormElement");
    if (!this.form) return; // not on this page

    this.emailInput = document.getElementById("subscribe-email");
    this.firstNameInput = document.getElementById("subscribe-first-name");
    this.lastNameInput = document.getElementById("subscribe-last-name");
    this.hpInput = document.getElementById("subscribe-hp");
    this.submitBtn = document.getElementById("subscribeSubmitBtn");
    this.successMessage = document.getElementById("subscribeSuccessMessage");

    this.isSubmitting = false;

    this.init();
  }

  init() {
    // Prefill hidden fields
    this.populateHiddenFields();

    // Live validation to enable/disable submit
    this.emailInput.addEventListener("input", () => this.updateSubmitButton());
    this.firstNameInput.addEventListener("input", () =>
      this.updateSubmitButton()
    );
    this.lastNameInput.addEventListener("input", () =>
      this.updateSubmitButton()
    );

    // Submit handler
    this.form.addEventListener("submit", (e) => this.handleSubmit(e));

    // Enable submit on initial load if valid
    this.updateSubmitButton();
  }

  populateHiddenFields() {
    const tsEl = document.getElementById("subscribeTimestampInput");
    const uaEl = document.getElementById("subscribeUserAgentInput");

    if (tsEl) tsEl.value = new Date().toISOString();
    if (uaEl) uaEl.value = navigator.userAgent;
  }

  isValidEmail(value) {
    // Simple but effective email pattern
    return /\S+@\S+\.\S+/.test(value);
  }

  updateSubmitButton() {
    const hasEmail = this.emailInput.value.trim().length > 0;
    const emailOk = this.isValidEmail(this.emailInput.value.trim());
    const honeyPotEmpty = !this.hpInput.value;

    this.submitBtn.disabled = !(hasEmail && emailOk && honeyPotEmpty);
  }

  async handleSubmit(e) {
    e.preventDefault();

    if (this.isSubmitting) return;

    // Final validation guard
    if (this.submitBtn.disabled) return;

    // Spam trap check
    if (this.hpInput.value) return; // silently drop

    this.isSubmitting = true;
    const originalText = this.submitBtn.textContent;
    this.submitBtn.textContent = "Submitting...";
    this.submitBtn.disabled = true;

    try {
      // Build a whitelisted payload only with the required fields
      const formData = new FormData();
      formData.append("email", this.emailInput.value.trim());
      formData.append("firstName", this.firstNameInput.value.trim());
      formData.append("lastName", this.lastNameInput.value.trim());
      // Prefer values from hidden inputs if present, else compute
      const tsEl = document.getElementById("subscribeTimestampInput");
      const uaEl = document.getElementById("subscribeUserAgentInput");
      formData.append("timestamp", tsEl?.value || new Date().toISOString());
      formData.append("userAgent", uaEl?.value || navigator.userAgent);

      await fetch(this.form.action, {
        method: "POST",
        mode: "no-cors",
        body: formData,
      });

      this.showSuccess();
    } catch (err) {
      console.error("Subscription failed:", err);
      // Still show success due to no-cors blind POST
      this.showSuccess();
    } finally {
      this.submitBtn.textContent = originalText;
      this.isSubmitting = false;
    }
  }

  showSuccess() {
    if (this.successMessage) {
      this.successMessage.style.display = "block";
      setTimeout(() => {
        this.successMessage.style.display = "none";
        this.resetForm();
      }, 2500);
    } else {
      this.resetForm();
    }
  }

  resetForm() {
    this.form.reset();
    this.populateHiddenFields();
    this.updateSubmitButton();
  }
}

// Boot
document.addEventListener("DOMContentLoaded", () => {
  try {
    window.subscribeWidget = new SubscribeWidget();
  } catch (e) {
    console.error("SubscribeWidget init error:", e);
  }
});
