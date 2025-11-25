(function() {
    function fixLogoLink() {
        // Find all logo links
        const logoLinks = document.querySelectorAll('.md-logo, .md-header__button.md-logo, a[data-md-component="logo"]');

        logoLinks.forEach(function(link) {
            // Remove target attribute if it exists
            link.removeAttribute('target');

            // Add click handler to prevent default and navigate in same tab
            link.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                window.location.href = this.href;
            }, true); // Use capture phase to run before other handlers
        });
    }

    // Run immediately
    fixLogoLink();

    // Run after DOM is loaded
    document.addEventListener('DOMContentLoaded', fixLogoLink);

    // Run after a delay to ensure all plugins have loaded
    setTimeout(fixLogoLink, 100);
    setTimeout(fixLogoLink, 500);
    setTimeout(fixLogoLink, 1000);
})();
