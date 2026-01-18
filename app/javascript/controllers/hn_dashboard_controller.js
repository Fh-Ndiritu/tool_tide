import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas", "stats"]
  static values = {
    averages: Object,
    today: Object
  }

  connect() {
    this.initChart()
  }

  initChart() {
    const ctx = this.canvasTarget.getContext("2d")

    // Prepare Data
    // Averages: Key is HHMM (0, 30, 100 ... 2330). Need to sort labels.
    const allTimeBuckets = Object.keys(this.averagesValue).map(Number).sort((a, b) => a - b)

    // Format labels (HH:MM)
    const labels = allTimeBuckets.map(t => {
      const h = Math.floor(t / 100).toString().padStart(2, '0')
      const m = (t % 100).toString().padStart(2, '0')
      return `${h}:${m}`
    })

    const avgData = allTimeBuckets.map(t => this.averagesValue[t] || 0)

    // Today: might be partial. Map to same buckets.
    const todayData = allTimeBuckets.map(t => this.todayValue[t] || null)
    // using null to break line if we haven't reached that time yet?
    // Or 0? If it's "future", better be null.
    // Assuming backend provided todayValue for *past* buckets only.

    // Create Gradients
    const gradientToday = ctx.createLinearGradient(0, 0, 0, 400);
    gradientToday.addColorStop(0, 'rgba(249, 115, 22, 0.4)');   // Orange-500
    gradientToday.addColorStop(1, 'rgba(249, 115, 22, 0.0)');

    const gradientAvg = ctx.createLinearGradient(0, 0, 0, 400);
    gradientAvg.addColorStop(0, 'rgba(59, 130, 246, 0.2)');    // Blue-500
    gradientAvg.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Historical Average',
            data: avgData,
            borderColor: '#3b82f6', // blue-500
            backgroundColor: gradientAvg,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 4,
            fill: true,
            tension: 0.4
          },
          {
            label: "Today's Activity",
            data: todayData,
            borderColor: '#f97316', // orange-500
            backgroundColor: gradientToday,
            borderWidth: 3,
            pointBackgroundColor: '#fff',
            pointBorderColor: '#f97316',
            pointRadius: 4,
            pointHoverRadius: 6,
            fill: true,
            tension: 0.4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
            align: 'end',
            labels: {
              usePointStyle: true,
              boxWidth: 8,
              font: { family: "'Inter', sans-serif", size: 12 }
            }
          },
          tooltip: {
            mode: 'index',
            intersect: false,
            padding: 10,
            cornerRadius: 8,
            backgroundColor: 'rgba(255, 255, 255, 0.9)',
            titleColor: '#1f2937',
            bodyColor: '#4b5563',
            borderColor: '#e5e7eb',
            borderWidth: 1,
            titleFont: { family: "'Inter', sans-serif", size: 14, weight: 'bold' },
            bodyFont: { family: "'Inter', sans-serif", size: 13 }
          },
          title: { display: false }
        },
        scales: {
            x: {
                grid: { display: false },
                ticks: {
                    font: { family: "'Inter', sans-serif", size: 11 },
                    color: '#9ca3af',
                    maxTicksLimit: 12
                }
            },
          y: {
            beginAtZero: true,
            grid: {
                color: '#f3f4f6',
                borderDash: [2, 2]
            },
             ticks: {
                    font: { family: "'Inter', sans-serif", size: 11 },
                    color: '#9ca3af'
                },
             border: { display: false }
          }
        },
        interaction: {
          mode: 'nearest',
          axis: 'x',
          intersect: false
        }
      }
    })
  }

  // Called when Turbo Stream replaces the stats element
  updateStats(event) {
    // The "stats" target was replaced. It has new data attributes.
    // Read them and add to chart.
    const element = this.statsTarget
    const count = parseInt(element.dataset.latestCount)
    const timeBucket = parseInt(element.dataset.latestBucket)

    if (!isNaN(count) && !isNaN(timeBucket)) {
       this.addDataPoint(timeBucket, count)
    }
  }

  addDataPoint(timeBucket, count) {
    if (!this.chart) return

    // Find index of bucket
    // We assume buckets are fixed (0, 30, ... 2330).
    // Re-calculating index is safest.
    const allTimeBuckets = Object.keys(this.averagesValue).map(Number).sort((a, b) => a - b)
    const index = allTimeBuckets.indexOf(timeBucket)

    if (index !== -1) {
      // Update Today's dataset (index 1)
      this.chart.data.datasets[1].data[index] = count
      this.chart.update()
    }
  }

  // Triggered by mutation observer or simplify:
  // We can use a Stimulus "targetConnected" callback.
  statsTargetConnected(element) {
    // If we have a chart, try to update it
    if (this.chart) {
      const count = element.dataset.latestCount
      const bucket = element.dataset.latestBucket
      if (count && bucket) {
        this.addDataPoint(parseInt(bucket), parseInt(count))
      }
    }
  }
}
