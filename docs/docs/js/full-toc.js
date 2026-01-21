/**
 * Full TOC Generator for Material for MkDocs
 * Generates a complete table of contents for long single-page documents
 * Only activates on pages with more than 10 headings
 */
(function() {
    'use strict';

    // Wait for DOM to be ready
    document.addEventListener('DOMContentLoaded', function() {
        // Only run on pages that might need full TOC
        const headings = document.querySelectorAll('article h2');
        if (headings.length < 5) return;

        // Find or create the TOC container
        const tocNav = document.querySelector('.md-sidebar--secondary .md-nav--secondary');
        if (!tocNav) return;

        // Build the complete TOC
        buildFullTOC(tocNav, headings);

        // Set up scroll spy
        setupScrollSpy(headings);
    });

    function buildFullTOC(tocNav, headings) {
        // Find the list container
        let tocList = tocNav.querySelector('.md-nav__list');
        if (!tocList) {
            tocList = document.createElement('ul');
            tocList.className = 'md-nav__list';
            tocList.setAttribute('data-md-component', 'toc');
            tocNav.appendChild(tocList);
        }

        // Clear existing items
        tocList.innerHTML = '';

        // Add all h2 headings to TOC
        headings.forEach(function(heading, index) {
            const id = heading.id || heading.getAttribute('id');
            if (!id) return;

            const li = document.createElement('li');
            li.className = 'md-nav__item';

            const a = document.createElement('a');
            a.href = '#' + id;
            a.className = 'md-nav__link';
            a.setAttribute('data-full-toc', 'true');

            const span = document.createElement('span');
            span.className = 'md-ellipsis';
            span.textContent = heading.textContent.trim();

            a.appendChild(span);
            li.appendChild(a);
            tocList.appendChild(li);
        });

        // Apply styling for full TOC
        tocNav.classList.add('full-toc-enabled');
    }

    function setupScrollSpy(headings) {
        const tocLinks = document.querySelectorAll('.md-nav__link[data-full-toc]');
        if (tocLinks.length === 0) return;

        // Track which heading is currently in view
        let currentActive = null;

        function updateActiveLink() {
            const scrollPos = window.scrollY + 100; // Offset for header

            let activeHeading = null;
            headings.forEach(function(heading) {
                if (heading.offsetTop <= scrollPos) {
                    activeHeading = heading;
                }
            });

            if (activeHeading && activeHeading.id !== currentActive) {
                currentActive = activeHeading.id;

                // Remove active class from all links
                tocLinks.forEach(function(link) {
                    link.classList.remove('md-nav__link--active');
                });

                // Add active class to current link
                const activeLink = document.querySelector(
                    '.md-nav__link[data-full-toc][href="#' + currentActive + '"]'
                );
                if (activeLink) {
                    activeLink.classList.add('md-nav__link--active');

                    // Scroll the active link into view in the TOC
                    const tocContainer = document.querySelector('.md-sidebar--secondary .md-sidebar__scrollwrap');
                    if (tocContainer) {
                        const linkRect = activeLink.getBoundingClientRect();
                        const containerRect = tocContainer.getBoundingClientRect();

                        if (linkRect.top < containerRect.top || linkRect.bottom > containerRect.bottom) {
                            activeLink.scrollIntoView({ block: 'center', behavior: 'smooth' });
                        }
                    }
                }
            }
        }

        // Update on scroll with throttling
        let ticking = false;
        window.addEventListener('scroll', function() {
            if (!ticking) {
                window.requestAnimationFrame(function() {
                    updateActiveLink();
                    ticking = false;
                });
                ticking = true;
            }
        });

        // Initial update
        updateActiveLink();
    }
})();
