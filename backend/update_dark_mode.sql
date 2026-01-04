-- ============================================
-- UPDATE DARK MODE EXTENSION
-- Run this SQL on your MySQL database
-- This version is more robust and works on more websites
-- ============================================

UPDATE `extensions` 
SET `js_code` = '(function() {
  // Prevent duplicate injection
  if (window.dinoDarkModeInjected) return;
  window.dinoDarkModeInjected = true;
  
  // Create a style element for dark mode
  const darkModeStyle = document.createElement("style");
  darkModeStyle.id = "dino-dark-mode";
  darkModeStyle.textContent = `
    html {
      filter: invert(1) hue-rotate(180deg) !important;
      background: #1a1a2e !important;
    }
    
    /* Preserve images, videos, and media */
    img, video, picture, canvas, svg, 
    [style*="background-image"],
    iframe, embed, object {
      filter: invert(1) hue-rotate(180deg) !important;
    }
    
    /* Handle background images in elements */
    *[style*="background-image"] {
      filter: invert(1) hue-rotate(180deg) !important;
    }
    
    /* Ensure emojis display correctly */
    img[src*="emoji"], img[alt*="emoji"] {
      filter: none !important;
    }
  `;
  
  document.documentElement.appendChild(darkModeStyle);
  
  // Use MutationObserver to handle dynamically loaded content
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1) {
          // Re-apply filter to new images/videos
          const media = node.querySelectorAll ? node.querySelectorAll("img, video, picture, canvas, iframe") : [];
          media.forEach((el) => {
            if (!el.style.filter || !el.style.filter.includes("invert")) {
              el.style.filter = "invert(1) hue-rotate(180deg)";
            }
          });
        }
      });
    });
  });
  
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
  
  console.log("[Dino] Dark Mode Pro enabled");
})();',
`description` = 'Force dark mode on any website for comfortable night browsing. Works with dynamic content and preserves images.'
WHERE `name` = 'Dark Mode Pro';

-- Verify the update
SELECT id, name, description FROM extensions WHERE name = 'Dark Mode Pro';
