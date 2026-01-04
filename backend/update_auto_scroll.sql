-- ============================================
-- UPDATE AUTO SCROLL EXTENSION
-- Run this SQL on your MySQL database
-- ============================================

UPDATE `extensions` 
SET `js_code` = '(function() {
  // Prevent duplicate injection
  if (window.dinoAutoScrollInjected) return;
  window.dinoAutoScrollInjected = true;
  
  let isScrolling = false;
  let scrollSpeed = 1;
  let scrollInterval = null;
  
  // Create floating control button
  const btn = document.createElement("div");
  btn.id = "dino-scroll-btn";
  btn.innerHTML = "▶";
  btn.style.cssText = `
    position: fixed;
    bottom: 100px;
    right: 20px;
    width: 50px;
    height: 50px;
    background: linear-gradient(135deg, #00FFA3 0%, #4CC9F0 100%);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    color: #1a1a2e;
    cursor: pointer;
    z-index: 999999;
    box-shadow: 0 4px 15px rgba(0, 255, 163, 0.4);
    transition: all 0.3s ease;
    user-select: none;
    touch-action: manipulation;
  `;
  
  // Speed control (appears when scrolling)
  const speedControl = document.createElement("div");
  speedControl.id = "dino-speed-control";
  speedControl.style.cssText = `
    position: fixed;
    bottom: 160px;
    right: 20px;
    background: rgba(26, 26, 46, 0.95);
    border-radius: 25px;
    padding: 10px;
    display: none;
    flex-direction: column;
    gap: 5px;
    z-index: 999998;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
  `;
  speedControl.innerHTML = `
    <button id="dino-speed-up" style="width:30px;height:30px;border:none;border-radius:50%;background:#00FFA3;color:#1a1a2e;font-weight:bold;cursor:pointer;">+</button>
    <span id="dino-speed-label" style="color:#fff;font-size:12px;text-align:center;">1x</span>
    <button id="dino-speed-down" style="width:30px;height:30px;border:none;border-radius:50%;background:#FF6B6B;color:#fff;font-weight:bold;cursor:pointer;">-</button>
  `;
  
  document.body.appendChild(speedControl);
  document.body.appendChild(btn);
  
  function updateSpeedLabel() {
    const label = document.getElementById("dino-speed-label");
    if (label) label.textContent = scrollSpeed + "x";
  }
  
  function startScrolling() {
    isScrolling = true;
    btn.innerHTML = "⏸";
    btn.style.background = "linear-gradient(135deg, #FF6B6B 0%, #FF8E53 100%)";
    speedControl.style.display = "flex";
    scrollInterval = setInterval(() => {
      window.scrollBy(0, scrollSpeed);
    }, 50);
  }
  
  function stopScrolling() {
    isScrolling = false;
    btn.innerHTML = "▶";
    btn.style.background = "linear-gradient(135deg, #00FFA3 0%, #4CC9F0 100%)";
    speedControl.style.display = "none";
    if (scrollInterval) {
      clearInterval(scrollInterval);
      scrollInterval = null;
    }
  }
  
  // Button click handler
  btn.addEventListener("click", function(e) {
    e.preventDefault();
    e.stopPropagation();
    if (isScrolling) {
      stopScrolling();
    } else {
      startScrolling();
    }
  });
  
  // Speed controls
  document.getElementById("dino-speed-up").addEventListener("click", function(e) {
    e.stopPropagation();
    if (scrollSpeed < 5) {
      scrollSpeed++;
      updateSpeedLabel();
    }
  });
  
  document.getElementById("dino-speed-down").addEventListener("click", function(e) {
    e.stopPropagation();
    if (scrollSpeed > 1) {
      scrollSpeed--;
      updateSpeedLabel();
    }
  });
  
  // Hover effects
  btn.addEventListener("mouseenter", () => btn.style.transform = "scale(1.1)");
  btn.addEventListener("mouseleave", () => btn.style.transform = "scale(1)");
  
  console.log("[Dino] Auto Scroll ready - tap the button to start/stop");
})();',
`description` = 'Automatically scroll pages at a comfortable reading pace. Tap the floating button to start/stop, use +/- to adjust speed.'
WHERE `name` = 'Auto Scroll';

-- Verify the update
SELECT id, name, description, LEFT(js_code, 100) as js_preview FROM extensions WHERE name = 'Auto Scroll';
