/*
 *      Copyright (C) 2005-2008 Team XBMC
 *      http://www.xbmc.org
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with XBMC; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */
#if defined(__APPLE__) && defined(__arm__)
//hack around problem with xbmc's typedef int BOOL
// and obj-c's typedef unsigned char BOOL
#define BOOL XBMC_BOOL 
#include "system.h"
#undef BOOL

#ifdef HAS_EGL
#define BOOL XBMC_BOOL 
#include "WinSystemIOS.h"
#include "utils/log.h"
#include "SpecialProtocol.h"
#include "Settings.h"
#include "Texture.h"
#include "linux/XRandR.h"
#include <vector>
#undef BOOL

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../BackRow/BackRow.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "XBMCController.h"
#import "XBMCEAGLView.h"
#import <dlfcn.h>

CWinSystemIOS::CWinSystemIOS() : CWinSystemBase()
{
  m_eWindowSystem = WINDOW_SYSTEM_IOS;

  m_iVSyncErrors = 0;
}

CWinSystemIOS::~CWinSystemIOS()
{
}

bool CWinSystemIOS::InitWindowSystem()
{
	return CWinSystemBase::InitWindowSystem();
}

bool CWinSystemIOS::DestroyWindowSystem()
{
  return true;
}

bool CWinSystemIOS::CreateNewWindow(const CStdString& name, bool fullScreen, RESOLUTION_INFO& res, PHANDLE_EVENT_FUNC userFunction)
{
	
  NSLog(@"%s", __PRETTY_FUNCTION__);
	
  if(!SetFullScreen(fullScreen, res, false))
    return false;

  [g_xbmcController setFramebuffer];

  m_bWindowCreated = true;

  m_eglext  = " ";
  m_eglext += (const char*) glGetString(GL_EXTENSIONS);
  m_eglext += " ";

  CLog::Log(LOGDEBUG, "EGL_EXTENSIONS:%s", m_eglext.c_str());
  return true;
}

bool CWinSystemIOS::DestroyWindow()
{
  return true;
}

bool CWinSystemIOS::ResizeWindow(int newWidth, int newHeight, int newLeft, int newTop)
{
	
  NSLog(@"%s", __PRETTY_FUNCTION__);
	
  if (m_nWidth != newWidth || m_nHeight != newHeight)
  {
    m_nWidth  = newWidth;
    m_nHeight = newHeight;
  }

  CRenderSystemGLES::ResetRenderSystem(newWidth, newHeight, false, 0);

  return true;
}

bool CWinSystemIOS::SetFullScreen(bool fullScreen, RESOLUTION_INFO& res, bool blankOtherDisplays)
{
	
  NSLog(@"%s", __PRETTY_FUNCTION__);
	
  m_nWidth      = res.iWidth;
  m_nHeight     = res.iHeight;
  m_bFullScreen = fullScreen;

  CRenderSystemGLES::ResetRenderSystem(res.iWidth, res.iHeight, fullScreen, res.fRefreshRate);
  
  return true;
}

void CWinSystemIOS::UpdateResolutions()
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  int w = 0;
  int h = 0;
#if 1
  w = [BRWindow interfaceFrame].size.width;
  h = [BRWindow interfaceFrame].size.height;
  double fps = [g_xbmcController getDisplayLinkFPS];
#else
  if ([g_xbmcController getOrientation] == UIInterfaceOrientationPortrait)
  {
    w = [[UIScreen mainScreen] bounds].size.width;
    h = [[UIScreen mainScreen] bounds].size.height;
  }
  else
  {
    h = [[UIScreen mainScreen] bounds].size.width;
    w = [[UIScreen mainScreen] bounds].size.height;
  }
  double fps = [g_xbmcController getDisplayLinkFPS];

  NSLog(@"%s UpdateResolutions width=%d, height=%d, fps=%f", 
		__PRETTY_FUNCTION__, w, h, fps);
#endif
  UpdateDesktopResolution(g_settings.m_ResInfo[RES_DESKTOP], 0, w, h, fps);
  [pool release];
}

bool CWinSystemIOS::IsExtSupported(const char* extension)
{
  if(strncmp(extension, "EGL_", 4) != 0)
    return CRenderSystemGLES::IsExtSupported(extension);

  CStdString name;

  name  = " ";
  name += extension;
  name += " ";

  return m_eglext.find(name) != string::npos;
}

bool CWinSystemIOS::BeginRender()
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  bool rtn;

  [g_xbmcController setFramebuffer];

  rtn = CRenderSystemGLES::BeginRender();

  [pool release];
  return rtn;
}

bool CWinSystemIOS::EndRender()
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  bool rtn;

  rtn = CRenderSystemGLES::EndRender();

  [pool release];
  return rtn;
}

void CWinSystemIOS::InitDisplayLink(void)
{
}
void CWinSystemIOS::DeinitDisplayLink(void)
{
}
double CWinSystemIOS::GetDisplayLinkFPS(void)
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  double fps;

  fps = [g_xbmcController getDisplayLinkFPS];

  [pool release];
  return fps;
}

bool CWinSystemIOS::PresentRenderImpl()
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  
  //glFlush;
  //glFinish();
  [g_xbmcController presentFramebuffer];

  [pool release];
  return true;
}

void CWinSystemIOS::SetVSyncImpl(bool enable)
{
  #if 0	
    // set swapinterval if possible
    void *eglSwapInterval;	
    eglSwapInterval = dlsym( RTLD_DEFAULT, "eglSwapInterval" );
    if ( eglSwapInterval )
    {
      ((void(*)(int))eglSwapInterval)( 1 ) ;
    }
  #endif
  m_iVSyncMode = 10;
}

void CWinSystemIOS::ShowOSMouse(bool show)
{
}

void CWinSystemIOS::NotifyAppActiveChange(bool bActivated)
{
  if (bActivated && m_bWasFullScreenBeforeMinimize && !g_graphicsContext.IsFullScreenRoot())
    g_graphicsContext.ToggleFullScreenRoot();
}

bool CWinSystemIOS::Minimize()
{
  m_bWasFullScreenBeforeMinimize = g_graphicsContext.IsFullScreenRoot();
  if (m_bWasFullScreenBeforeMinimize)
    g_graphicsContext.ToggleFullScreenRoot();

  return true;
}

bool CWinSystemIOS::Restore()
{
  return false;
}

bool CWinSystemIOS::Hide()
{
  return true;
}

bool CWinSystemIOS::Show(bool raise)
{
  return true;
}
#endif

#endif
