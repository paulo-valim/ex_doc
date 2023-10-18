import throttle from 'lodash.throttle'
import { qs } from '../helpers'

const BREAKPOINT = 768
const ANIMATION_DURATION = 300

const SIDEBAR_TOGGLE_SELECTOR = '.sidebar-toggle'
const CONTENT_SELECTOR = '.content'
const SEARCHBAR_TOGGLE_SELECTOR = '.searchbar-toggle'

const userPref = {
  CLOSED: 'closed',
  OPEN: 'open',
  NO_PREF: 'no_pref'
}

const SIDEBAR_CLASS = {
  opened: 'sidebar-opened',
  openingStart: 'sidebar-opening-start',
  opening: 'sidebar-opening',
  closed: 'sidebar-closed',
  closingStart: 'sidebar-closing-start',
  closing: 'sidebar-closing'
}

const SIDEBAR_CLASSES = Object.values(SIDEBAR_CLASS)

const state = {
  // Keep track of the current timeout to clear it if needed
  togglingTimeout: null,
  // Record window width on resize to update sidebar state only when it actually changes
  lastWindowWidth: window.innerWidth,
  // No_PREF is defaults to OPEN behavior
  sidebarPreference: userPref.NO_PREF
}

/**
 * Initializes the toggleable sidebar drawer.
 */
export function initialize () {
  setDefaultSidebarState()
  addEventListeners()
}

function setDefaultSidebarState () {
  // check & set persistent session state
  const persistentSessionState = sessionStorage.getItem('sidebar_state')
  // set default for closed state only, so sidebar will still auto close on window resize
  if (persistentSessionState === 'closed' || isScreenSmall()) {
    setClass(SIDEBAR_CLASS.closed)
    qs(SIDEBAR_TOGGLE_SELECTOR).setAttribute('aria-expanded', 'false')
  } else {
    setClass(SIDEBAR_CLASS.opened)
    qs(SIDEBAR_TOGGLE_SELECTOR).setAttribute('aria-expanded', 'true')
  }
}

function isScreenSmall () {
  return window.matchMedia(`screen and (max-width: ${BREAKPOINT}px)`).matches
}

function setClass (...classes) {
  document.body.classList.remove(...SIDEBAR_CLASSES)
  document.body.classList.add(...classes)
}

function addEventListeners () {
  qs(SIDEBAR_TOGGLE_SELECTOR).addEventListener('click', (event) => {
    toggleSidebar()
    setPreference()
    toggleIcon('sidebar-icon')
  })

  qs(SEARCHBAR_TOGGLE_SELECTOR).addEventListener('click', (event) => {
    toggleSidebar()
    setPreference()
    toggleIcon('searchbar-icon')
  })

  qs(CONTENT_SELECTOR).addEventListener('click', (event) => {
    closeSidebarIfSmallScreen()
  })

  window.addEventListener(
    'resize',
    throttle((event) => {
      adoptSidebarToWindowSize()
    }, 100)
  )
}

/**
 * Either opens or closes the sidebar depending on the current state.
 *
 * @returns {Promise} A promise resolving once the animation is finished.
 */
export function toggleSidebar () {
  if (isSidebarOpen()) {
    return closeSidebar()
  } else {
    return openSidebar()
  }
}

function isSidebarOpen () {
  return (
    document.body.classList.contains(SIDEBAR_CLASS.opened) ||
    document.body.classList.contains(SIDEBAR_CLASS.opening)
  )
}

/**
 * Opens the sidebar by applying an animation.
 *
 * @returns {Promise} A promise resolving once the animation is finished.
 */
export function openSidebar () {
  clearTimeoutIfAny()
  sessionStorage.setItem('sidebar_state', 'opened')
  qs(SIDEBAR_TOGGLE_SELECTOR).setAttribute('aria-expanded', 'true')

  requestAnimationFrame(() => {
    setClass(SIDEBAR_CLASS.openingStart)

    requestAnimationFrame(() => {
      setClass(SIDEBAR_CLASS.opening)

      return new Promise((resolve, reject) => {
        state.togglingTimeout = setTimeout(() => {
          setClass(SIDEBAR_CLASS.opened)
          resolve()
        }, ANIMATION_DURATION)
      })
    })
  })
}

/**
 * Closes the sidebar by applying an animation.
 *
 * @returns {Promise} A promise resolving once the animation is finished.
 */
export function closeSidebar () {
  clearTimeoutIfAny()
  sessionStorage.setItem('sidebar_state', 'closed')
  qs(SIDEBAR_TOGGLE_SELECTOR).setAttribute('aria-expanded', 'false')

  requestAnimationFrame(() => {
    setClass(SIDEBAR_CLASS.closingStart)

    requestAnimationFrame(() => {
      setClass(SIDEBAR_CLASS.closing)

      return new Promise((resolve, reject) => {
        state.togglingTimeout = setTimeout(() => {
          setClass(SIDEBAR_CLASS.closed)
          resolve()
        }, ANIMATION_DURATION)
      })
    })
  })
}

function clearTimeoutIfAny () {
  if (state.togglingTimeout) {
    clearTimeout(state.togglingTimeout)
    state.togglingTimeout = null
  }
}

/**
 * Handles updating the sidebar state on window resize
 *
 * WHEN the window width has changed
 * AND the user sidebar preference is OPEN or NO_PREF
 * THEN adjust the sidebar state according to screen size
 */
function adoptSidebarToWindowSize () {
  // See https://github.com/elixir-lang/ex_doc/issues/736#issuecomment-307371291
  if (state.lastWindowWidth !== window.innerWidth) {
    state.lastWindowWidth = window.innerWidth
    if (
      state.sidebarPreference === userPref.OPEN ||
      state.sidebarPreference === userPref.NO_PREF
    ) {
      setDefaultSidebarState()
    }
  }
}

function closeSidebarIfSmallScreen () {
  const sidebarCoversContent = isScreenSmall()
  if (sidebarCoversContent && isSidebarOpen()) {
    closeSidebar()
  }
}

/**
 * Track the sidebar preference for the user
 */
function setPreference () {
  switch (state.sidebarPreference) {
    case userPref.OPEN:
      state.sidebarPreference = userPref.CLOSED
      break
    case userPref.CLOSED:
      state.sidebarPreference = userPref.OPEN
      break
    case userPref.NO_PREF:
      isSidebarOpen()
        ? (state.sidebarPreference = userPref.OPEN)
        : (state.sidebarPreference = userPref.CLOSED)
  }
}

function toggleIcon (iconId) {
  const icon = document.getElementById(iconId)

  // Check the current class of the icon
  if (icon.classList.contains('ri-menu-unfold-line')) {
    // If it has the 'ri-menu-unfold-line' class, change it to the new icon class
    icon.classList.remove('ri-menu-unfold-line')
    icon.classList.add('ri-menu-fold-line')
  } else {
    // If it has the 'ri-menu-fold-line' class, change it back to the original icon class
    icon.classList.remove('ri-menu-fold-line')
    icon.classList.add('ri-menu-unfold-line')
  }
}
