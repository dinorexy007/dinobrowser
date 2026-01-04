document.addEventListener('DOMContentLoaded', () => {

    // Typing animation for Hero Search Bar
    const searchBar = document.querySelector('.search-bar-mock');
    const texts = ['Search the web...', 'T-Rex dinosaurs', 'Flutter development', 'Offline articles'];
    let textIndex = 0;

    function typeText() {
        // Create text element if not exists
        if (!searchBar.querySelector('span')) {
            const span = document.createElement('span');
            span.style.color = '#fff';
            span.style.opacity = '0.7';
            span.style.marginLeft = '15px';
            span.style.lineHeight = '45px';
            searchBar.appendChild(span);
        }

        const span = searchBar.querySelector('span');
        const currentText = texts[textIndex];
        let charIndex = 0;

        span.textContent = '';

        const typeInterval = setInterval(() => {
            if (charIndex < currentText.length) {
                span.textContent += currentText.charAt(charIndex);
                charIndex++;
            } else {
                clearInterval(typeInterval);
                setTimeout(eraseText, 2000);
            }
        }, 100);
    }

    function eraseText() {
        const span = searchBar.querySelector('span');
        let currentContent = span.textContent;

        const eraseInterval = setInterval(() => {
            if (currentContent.length > 0) {
                currentContent = currentContent.substring(0, currentContent.length - 1);
                span.textContent = currentContent;
            } else {
                clearInterval(eraseInterval);
                textIndex = (textIndex + 1) % texts.length;
                setTimeout(typeText, 500);
            }
        }, 50);
    }

    // Start typing animation
    typeText();

    // Workspace Card Hover Effect (Auto-play when not hovered)
    const cards = document.querySelectorAll('.workspace-card');
    let activeCardIndex = 0;

    setInterval(() => {
        // Only animate if user is not hovering sections
        if (!document.querySelector('#workspaces:hover')) {
            cards.forEach(c => c.style.transform = 'scale(1)');
            cards.forEach(c => c.style.borderColor = 'rgba(255,255,255,0.1)');

            if (cards[activeCardIndex]) {
                cards[activeCardIndex].style.transform = 'scale(1.05)';
                cards[activeCardIndex].style.borderColor = '#00E676';
            }

            activeCardIndex = (activeCardIndex + 1) % cards.length;
        }
    }, 2000);

    // Hero Phone 3D Tilt Effect
    const heroSection = document.getElementById('hero');
    const heroPhone = document.getElementById('hero-phone');

    if (heroSection && heroPhone) {
        heroSection.addEventListener('mousemove', (e) => {
            const xAxis = (window.innerWidth / 2 - e.pageX) / 25;
            const yAxis = (window.innerHeight / 2 - e.pageY) / 25;
            heroPhone.style.transform = `rotateY(${xAxis}deg) rotateX(${yAxis}deg)`;
        });

        // Reset on mouse leave
        heroSection.addEventListener('mouseleave', () => {
            heroPhone.style.transform = 'rotateY(0deg) rotateX(0deg)';
            heroPhone.style.transition = 'all 0.5s ease';
        });

        heroSection.addEventListener('mouseenter', () => {
            heroPhone.style.transition = 'none';
        });
    }

    // Extensions Toggle Animation
    const toggles = document.querySelectorAll('.toggle-switch');
    let toggleIndex = 0;

    setInterval(() => {
        // Randomly toggle switches to show activity
        if (toggles.length > 0 && !document.querySelector('#extensions:hover')) {
            const toggle = toggles[toggleIndex];
            toggle.classList.toggle('active');
            toggleIndex = (toggleIndex + 1) % toggles.length;
        }
    }, 1500);
});
