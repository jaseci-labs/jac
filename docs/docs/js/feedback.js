class FeedbackWidget {
    constructor() {
        this.container = document.getElementById('feedbackContainer');
        this.toggle = document.getElementById('feedbackToggle');
        this.form = document.getElementById('feedbackForm');
        this.formElement = document.getElementById('feedbackFormElement');
        this.ratingBtns = document.querySelectorAll('.rating-btn');
        this.submitBtn = document.getElementById('submitBtn');
        this.cancelBtn = document.getElementById('cancelBtn');
        this.successMessage = document.getElementById('successMessage');
        this.commentInput = document.getElementById('commentInput');

        this.selectedRating = null;
        this.isSubmitting = false;

        this.init();
    }

    init() {
        // Check if we should hide the form on main domain
        this.checkDomain();

        // Set up event listeners
        this.toggle.addEventListener('click', () => this.toggleForm());
        this.cancelBtn.addEventListener('click', () => this.closeForm());

        this.ratingBtns.forEach(btn => {
            btn.addEventListener('click', () => this.selectRating(btn));
        });

        // Add input listener for comment field
        this.commentInput.addEventListener('input', () => this.updateSubmitButton());

        this.formElement.addEventListener('submit', (e) => this.handleSubmit(e));

        // Close form when clicking outside
        document.addEventListener('click', (e) => {
            if (!this.container.contains(e.target)) {
                this.closeForm();
            }
        });

        // Populate hidden fields
        this.populateHiddenFields();
    }

    checkDomain() {
        const currentUrl = window.location.href;
        const mainDomainUrl = 'https://www.jac-lang.org/';

        // Only hide if we're exactly on the main domain (no path)
        if (currentUrl === mainDomainUrl) {
            this.container.style.display = 'none';
            return;
        }
    }

    toggleForm() {
        this.form.classList.toggle('active');
        if (this.form.classList.contains('active')) {
            this.populateHiddenFields();
        }
    }

    closeForm() {
        this.form.classList.remove('active');
        this.resetForm();
    }

    selectRating(btn) {
        // Remove selected class from all buttons
        this.ratingBtns.forEach(b => b.classList.remove('selected'));

        // Add selected class to clicked button
        btn.classList.add('selected');

        // Store rating
        this.selectedRating = btn.dataset.rating;
        document.getElementById('ratingInput').value = this.selectedRating;

        // Update submit button immediately after rating selection
        this.updateSubmitButton();
    }

    updateSubmitButton() {
        const comment = this.commentInput.value.trim();
        const hasRating = this.selectedRating !== null;
        const hasComment = comment.length > 0;

        console.log('Update Submit Button:', { hasRating, hasComment, comment: comment.length, rating: this.selectedRating });

        this.submitBtn.disabled = !(hasRating && hasComment);
    }

    populateHiddenFields() {
        document.getElementById('urlInput').value = window.location.href;
        document.getElementById('timestampInput').value = new Date().toISOString();
        document.getElementById('userAgentInput').value = navigator.userAgent;
        document.getElementById('pageTitleInput').value = document.title;
    }

    async handleSubmit(e) {
        e.preventDefault();

        if (this.isSubmitting) return;

        this.isSubmitting = true;
        this.submitBtn.disabled = true;
        this.submitBtn.textContent = 'Submitting...';

        try {
            const formData = new FormData(this.formElement);

            const response = await fetch(this.formElement.action, {
                method: 'POST',
                mode: 'no-cors',
                body: formData
            });

            // Show success message
            this.showSuccess();

        } catch (error) {
            console.error('Error submitting feedback:', error);
            // Still show success since no-cors mode doesn't give us response details
            this.showSuccess();
        }
    }

    showSuccess() {
        this.successMessage.classList.add('show');
        setTimeout(() => {
            this.successMessage.classList.remove('show');
            this.closeForm();
        }, 2000);
    }

    resetForm() {
        this.formElement.reset();
        this.ratingBtns.forEach(btn => btn.classList.remove('selected'));
        this.selectedRating = null;
        this.submitBtn.disabled = true;
        this.submitBtn.textContent = 'Submit';
        this.isSubmitting = false;
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.feedbackWidget = new FeedbackWidget();
});