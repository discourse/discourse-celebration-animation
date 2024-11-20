import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";

const OBJECT_NAME = "animationFirstVisit";

export default class CelebrationAnimation extends Component {
  @service animationEvent;
  @tracked images = [];
  @tracked showCanvas = null;
  animationFrameId = null;

  // the straggler is one of the images that intentionally lags behind the rest in the animation
  stragglerIndex = 4;

  constructor() {
    super(...arguments);

    const parsedSetting = JSON.parse(settings.animation_images);

    this.images = parsedSetting;

    this.images.forEach((image) => {
      image.img = new Image();
      image.img.onload = () => {
        this.updateImageTrajectory(image);
      };
      image.img.src = image.src;
    });

    this.animationEvent.addObserver("startAnimation", this, this.toggledAction);

    if (
      settings.display_mode.includes("first visit") ||
      settings.display_mode.includes("every other day")
    ) {
      if (
        settings.test_mode ||
        this.animationEvent.storageExpired(OBJECT_NAME)
      ) {
        this.animationEvent.setLocalStorage(OBJECT_NAME);
        this.showCanvas = true;
      }
    }
  }

  willDestroy() {
    super.willDestroy();
    this.showCanvas = false;
    window.removeEventListener("resize", () => this.resizeCanvas());
    this.animationEvent.removeObserver(
      "startAnimation",
      this,
      this.toggledAction
    );
  }

  updateImageTrajectory(image) {
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    const baseSpeed = 14; // overall speed

    const deltaX = viewportWidth;
    const deltaY = -viewportHeight;
    const slope = deltaY / deltaX; // diagonal trajectory

    // faster for wide viewports, slower for narrow viewports
    const speedAdjustmentFactor =
      viewportWidth < 650 ? 0.9 : viewportWidth > 1200 ? 1.5 : 1;
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
    const speedMultiplier = Math.max(
      minSpeed,
      1.2 - Math.pow((distanceFromMid - maxSpeedAt) / maxSpeedAt, 2)
    );

    return Math.min(speedMultiplier * maxSpeed, maxSpeed);
  }

  resizeCanvas(canvas) {
    // need to recalculate on resize or the speeds are way off
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    this.images.forEach((image) => {
      this.updateImageTrajectory(image);
    });
  }

  checkAnimationCompleted() {
    return this.images.every(
      (image) =>
        image.xPos > window.innerWidth || image.yPos > window.innerHeight
    );
  }

  @action
  toggledAction() {
    this.actionToggled = this.animationEvent.actionToggled;
    this.showCanvas = true;

    this.images.forEach((image) => {
      this.updateImageTrajectory(image);
    });
  }

  @action
  didInsertCanvas(element) {
    const context = element.getContext("2d");
    window.addEventListener("resize", () => this.resizeCanvas(element));
    this.resizeCanvas(element); // manually setup

    let stragglerDelayCount = 0; // reset straggler counter
    const viewportWidth = window.innerWidth;

    // Delay start on narrow viewports otherwise we get overlap
    const stragglerStartDelay = viewportWidth < 800 ? 70 : 0;

    const animate = () => {
      this.animationFrameId = requestAnimationFrame(animate);
      context.clearRect(0, 0, element.width, element.height);

      this.images.forEach((image, index) => {
        let speedMultiplier = this.calculateSpeedMultiplier(
          image.xPos,
          element.width
        );
        // larger images for larger viewports
        const scaleRatio = Math.min(Math.max(viewportWidth / 1110, 0.8), 1.1);

        const newWidth = 400 * scaleRatio; // scale images based on default width
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
          const nearCenter = Math.abs(image.xPos - centralPoint);
          if (nearCenter) {
            speedMultiplier *= 0.77;
          } else {
            speedMultiplier *= 1.4;
          }
        }

        image.xPos += image.xSpeed * speedMultiplier;
        image.yPos += image.ySpeed * speedMultiplier;
        context.drawImage(
          image.img,
          image.xPos,
          image.yPos,
          newWidth,
          newHeight
        );
      });

      if (this.checkAnimationCompleted()) {
        cancelAnimationFrame(this.animationFrameId);
        this.showCanvas = false;
        return;
      }
    };

    animate();
  }

  <template>
    {{#if this.showCanvas}}
      <canvas
        {{didInsert this.didInsertCanvas}}
        id="celebration-animation-canvas"
      ></canvas>
    {{/if}}
  </template>
}
