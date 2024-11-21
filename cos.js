const sliderContainer = document.querySelector('.slider-container');
const slides = document.querySelectorAll('.slide');

let currentIndex = 0;

// Funkcja do aktualizacji slidera
function updateSlider() {
  const offset = -currentIndex * 100;
  sliderContainer.style.transform = `translateX(${offset}%)`;
}

// Automatyczna zmiana slajdów co 5 sekund
setInterval(() => {
  currentIndex = (currentIndex < slides.length - 1) ? currentIndex + 1 : 0;
  updateSlider();
}, 5000);
