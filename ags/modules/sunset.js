const { Widget, Utils, Variable } = imports.gi.ags;

const visible = Variable(false);
const temperature = Variable(2500);

let timeout = null;
function applyTemp(value) {
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(() => {
        Utils.execAsync(`hyprsunset -t ${Math.floor(value)}`);
    }, 20);
}

const slider = Widget.Slider({
    min: 1000,
    max: 6500,
    value: temperature.value,
    drawValue: false,
    hexpand: true,

    onChange: ({ value }) => {
        temperature.value = value;
        applyTemp(value);
    },
});

const window = Widget.Window({
    name: "sunset",
    anchor: ["top"],
    margins: [40, 0, 0, 0],
    visible: visible.value,

    child: Widget.Box({
        css: "padding: 10px; min-width: 400px;",
        children: [slider],
    }),
});

visible.connect("changed", () => {
    window.visible = visible.value;
});

export function toggleSunset() {
    visible.value = !visible.value;
}

export default window;
