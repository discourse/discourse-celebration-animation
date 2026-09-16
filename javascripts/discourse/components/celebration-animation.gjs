/* eslint-disable ember/no-observers */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";

const OBJECT_NAME = "animationFirstVisit";

export default class CelebrationAnimation extends Component {
  @service animationEvent;

  @tracked images = [];
  @tracked showAnimation = null;
  animationFrameId = null;

  // the straggler is one of the images that intentionally lags behind the rest in the animation
  stragglerIndex = 4;

  constructor() {
    super(...arguments);

    this.images = settings.animation_images
      .filter((image) => image.image)
      .map((image) => ({ ...image }));

    this.images.forEach((image) => {
      image.source = image.image;
      image.scale = Number(image.scale) > 0 ? Number(image.scale) : 1;
    });
    this.motionPreference = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    );
    this.motionPreference.addEventListener("change", this.motionChanged);

    this.animationEvent.addObserver("startAnimation", this, this.toggledAction);

    if (
      !this.motionPreference.matches &&
      this.images.length &&
      (settings.display_mode.includes("first visit") ||
        settings.display_mode.includes("every other day"))
    ) {
      if (
        settings.test_mode ||
        this.animationEvent.storageExpired(OBJECT_NAME)
      ) {
        this.animationEvent.setLocalStorage(OBJECT_NAME);
        this.showAnimation = true;
      }
    }
  }

  willDestroy() {
    super.willDestroy();
    cancelAnimationFrame(this.animationFrameId);
    this.motionPreference.removeEventListener("change", this.motionChanged);
    this.animationEvent.removeObserver(
      "startAnimation",
      this,
      this.toggledAction
    );
  }

  @action
  motionChanged() {
    if (this.motionPreference.matches) {
      cancelAnimationFrame(this.animationFrameId);
      this.showAnimation = false;
    }
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

  calculateSpeedMultiplier(xPos, viewportWidth) {
    const midPoint = viewportWidth / 2 - 200; // calculate and shift midpoint a little
    const distanceFromMid = Math.abs(xPos - midPoint) * 0.35;
    const maxSpeedAt = viewportWidth / 3;
    const minSpeed = 0.05;
    const maxSpeed = 1.3;

    // adjust speed based on location (slower in the middle, faster at edges)
    const speedMultiplier = Math.max(
      minSpeed,
      1.2 - Math.pow((distanceFromMid - maxSpeedAt) / maxSpeedAt, 2)
    );

    return Math.min(speedMultiplier * maxSpeed, maxSpeed);
  }

  resetTrajectories() {
    this.images.forEach((image) => {
      this.updateImageTrajectory(image);
    });
  }

  checkAnimationCompleted() {
    return this.images.every(
      (image) =>
        !image.img.naturalWidth ||
        image.xPos > window.innerWidth ||
        image.yPos + image.img.offsetHeight < 0
    );
  }

  @action
  toggledAction() {
    if (
      this.motionPreference.matches ||
      !this.images.length ||
      this.showAnimation
    ) {
      return;
    }
    this.showAnimation = true;

    this.images.forEach((image) => {
      this.updateImageTrajectory(image);
    });
  }

  @action
  didInsertAnimation(element) {
    const nodes = element.querySelectorAll("img");
    this.images.forEach((image, index) => {
      image.img = nodes[index];
    });
    this.resetTrajectories();

    let stragglerDelayCount = 0; // reset straggler counter
    const viewportWidth = window.innerWidth;

    // Delay start on narrow viewports otherwise we get overlap
    const stragglerStartDelay = viewportWidth < 800 ? 70 : 0;

    let startedAt;
    let previousTime;
    let elapsed = 0;
    const animate = (time) => {
      startedAt ??= time;
      if (
        !this.images.every((image) => image.img.complete) &&
        time - startedAt < 10000
      ) {
        this.animationFrameId = requestAnimationFrame(animate);
        return;
      }
      const step =
        previousTime === undefined
          ? 1
          : Math.min((time - previousTime) / (1000 / 60), 3);
      previousTime = time;
      elapsed += step;

      this.images.forEach((image, index) => {
        let speedMultiplier = this.calculateSpeedMultiplier(
          image.xPos,
          viewportWidth
        );
        // larger images for larger viewports
        const scaleRatio = Math.min(Math.max(viewportWidth / 1110, 0.8), 1.1);

        const newWidth = 400 * scaleRatio * image.scale;
        image.img.style.width = `${newWidth}px`;
        if (!image.img.naturalWidth) {
          return;
        }

        // handle straggler movement
        if (index === this.stragglerIndex) {
          if (stragglerDelayCount < stragglerStartDelay) {
            stragglerDelayCount += step;
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

        image.xPos += image.xSpeed * speedMultiplier * step;
        image.yPos += image.ySpeed * speedMultiplier * step;
        image.img.style.visibility = "visible";
        image.img.style.transform = `translate3d(${image.xPos}px, ${image.yPos}px, 0)`;
      });

      if (this.checkAnimationCompleted() || elapsed > 60 * 30) {
        cancelAnimationFrame(this.animationFrameId);
        this.showAnimation = false;
        return;
      }
      this.animationFrameId = requestAnimationFrame(animate);
    };

    this.animationFrameId = requestAnimationFrame(animate);
  }

  <template>
    {{#if this.showAnimation}}
      <div
        {{didInsert this.didInsertAnimation}}
        id="celebration-animation-overlay"
        aria-hidden="true"
      >
        {{#each this.images as |image|}}
          <img src={{image.source}} alt="" />
        {{/each}}
      </div>
    {{/if}}
  </template>
}
