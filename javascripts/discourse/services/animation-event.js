import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

export default class AnimationEvent extends Service {
  @service currentUser;

  @tracked startAnimation = false;
  currentTime = new Date().getTime();

  get isTestUser() {
    const groupIds = (settings.test_groups || "")
      .split("|")
      .filter(Boolean)
      .map(Number);
    return (
      this.currentUser?.groups?.some((group) => groupIds.includes(group.id)) ||
      false
    );
  }

  storageExpired(objectName) {
    const data = JSON.parse(localStorage.getItem(objectName));
    if (!data) {
      return true;
    }
    return this.currentTime > data.expiresAt;
  }

  setLocalStorage(objectName) {
    let expiryTime;

    if (
      objectName === "animationFirstVisit" &&
      settings.display_mode === "every other day and first solution"
    ) {
      expiryTime = 24 * 60 * 60 * 1000 * 2; // 48 hours
    } else {
      expiryTime = 24 * 60 * 60 * 1000; // 24 hours
    }

    const data = {
      timestamp: this.currentTime,
      expiresAt: this.currentTime + expiryTime,
    };
    localStorage.setItem(objectName, JSON.stringify(data));
  }

  @action
  handleActionToggled() {
    const overlay = document.getElementById("celebration-animation-overlay");
    if (!overlay) {
      // don't trigger if already animating
      this.startAnimation = !this.startAnimation;
    }
  }
}
