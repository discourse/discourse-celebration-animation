import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";

export default class animationEvent extends Service {
  @tracked startAnimation = false;

  @action
  handleActionToggled() {
    const canvas = document.getElementById("celebration-animation-canvas");
    if (!canvas) {
      // don't trigger if already animating
      this.startAnimation = true;
    }
  }
}
