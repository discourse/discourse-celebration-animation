import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from '@ember/service';

export default class CelebrationAnimation extends Component {
  @service animationEvent;
  @tracked images = [];
  @tracked showCanvas = null;
  @tracked
  hasSeenAnimation = localStorage.getItem("hasSeenAnimation") === "true";

  animationFrameId = null;
  stragglerIndex = 0;

  constructor() {
    super(...arguments);

    this.checkAnimationSeen();

    const parsedSetting = JSON.parse(settings.animation_images);

    this.images = parsedSetting;

    this.images.forEach(image => {
      image.img = new Image();
      image.img.onload = () => {
        this.updateImageTrajectory(image);
      };
      image.img.src = image.src;
    });

    this.animationEvent.addObserver('startAnimation', this, this.toggledAction);

    if (settings.display_mode === "first visit") {
      this.showCanvas = true;
    }
  }

updateImageTrajectory(image) {
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    const baseSpeed = 15;

    const deltaX = viewportWidth;
    const deltaY = -viewportHeight;
    const slope = deltaY / deltaX; // diagonal trajectory

    // faster for wide viewports, slower for narrow viewports
    const speedAdjustmentFactor = viewportWidth < 650 ? .9 : (viewportWidth > 1400 ? 1.5 : 1);
    this.speed = baseSpeed * speedAdjustmentFactor;

    image.xPos = image.xOffset * viewportWidth;
    image.yPos = image.yOffset * viewportHeight;

    // consistently scale speed
    image.xSpeed = this.speed / Math.sqrt(1 + slope * slope);
    image.ySpeed = image.xSpeed * slope;
}

  calculateSpeedMultiplier(xPos, canvasWidth) {
    const midPoint = canvasWidth / 2 - 200; // calculate and shift midpoint a little
    const distanceFromMid = Math.abs(xPos - midPoint) * 0.35;
    const maxSpeedAt = canvasWidth / 3;
    const minSpeed = 0.05;
    const maxSpeed = 1.3;

    // adjust speed based on location (slower in the middle, faster at edges)
    const speedMultiplier = Math.max(minSpeed, 1.2 - Math.pow((distanceFromMid - maxSpeedAt) / maxSpeedAt, 2));

    return Math.min(speedMultiplier * maxSpeed, maxSpeed);
  }

  setLocalStorage(state) {
    const currentTime = new Date().getTime();
    const data = {
      state,
      timestamp: currentTime
    };
    localStorage.setItem("hasSeenAnimation", JSON.stringify(data));
    this.hasSeenAnimation = state;
  }

  checkAnimationSeen() {
    const data = JSON.parse(localStorage.getItem("hasSeenAnimation"));
    if (data) {
      const currentTime = new Date().getTime();
      const totalTime = currentTime - data.timestamp;
      const day = 24 * 60 * 60 * 1000; // 24 hours

      this.hasSeenAnimation = data && totalTime < day && data.state === true;
    }
  }

  resizeCanvas(canvas) {    // need to recalculate on resize or the speeds are way off
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    this.images.forEach(image => {
      this.updateImageTrajectory(image);
    });
  }

  willDestroy() {
    super.willDestroy();
    this.showCanvas = false;
    window.removeEventListener('resize', () => this.resizeCanvas());
    this.animationEvent.removeObserver('startAnimation', this, this.toggledAction);
  }


   @action
   toggledAction() {
    this.actionToggled = this.animationEvent.actionToggled;
    this.showCanvas = true;

    this.images.forEach(image => {
      this.updateImageTrajectory(image);
    });
  }

  @action
  didInsertCanvas(element) {
    if (this.hasSeenAnimation && !settings.test_mode) {
      this.showCanvas = false;
      return;
    }

    const context = element.getContext('2d');
    window.addEventListener('resize', () => this.resizeCanvas(element));
    this.resizeCanvas(element); // manually setup

    let stragglerDelayCount = 0; // reset straggler counter
    const viewportWidth = window.innerWidth;

    // Delay start on narrow viewports otherwise we get overlap
    const stragglerStartDelay = viewportWidth < 800 ? 50 : 0; 

    const animate = () => {
      this.animationFrameId = requestAnimationFrame(animate);
      context.clearRect(0, 0, element.width, element.height);
      let allImagesOffCanvas = false;

        this.images.forEach((image, index) => {
        let speedMultiplier = this.calculateSpeedMultiplier(image.xPos, element.width);
            // larger images for larger viewports
            const scaleRatio = Math.min(Math.max(viewportWidth / 1110, 0.8), 1.1);

            // scale images based on set width
            const newWidth = 250 * scaleRatio;
            const aspectRatio = image.img.width / image.img.height;
            const newHeight = newWidth / aspectRatio;

            // handle straggler movement
            if (index === this.stragglerIndex) {
                if (stragglerDelayCount < stragglerStartDelay) {
                    stragglerDelayCount++;
                    return; // skip straggler until count is met
                }

                // slow near center, speed up otherwise
                const centralPoint = Math.max(viewportWidth * 0.5, 270);
                const nearCenter = Math.abs(image.xPos - centralPoint) ;
                if (nearCenter) {
                    speedMultiplier *= 0.8;
                } else {
                    speedMultiplier *= 1.4;
                }
            }

            image.xPos += image.xSpeed * speedMultiplier;
            image.yPos += image.ySpeed * speedMultiplier;
            context.drawImage(image.img, image.xPos, image.yPos, newWidth, newHeight);

            // checking if edges of image are still on the canvas
            if (image.xPos < element.width + newWidth && image.yPos > -newHeight) {
                allImagesOffCanvas = false;
            }
        });

        if (allImagesOffCanvas) {
            cancelAnimationFrame(this.animationFrameId);
            this.showCanvas = false;
        }
    };

    this.setLocalStorage(true);
    animate();
}

  <template>
    {{#if this.showCanvas}}
      <canvas {{didInsert this.didInsertCanvas}} id="celebration-animation-canvas"></canvas>
    {{/if}}
  </template>
}
