#include "midi_file_drag.h"

#include <ole2.h>
#include <shlobj.h>
#include <windows.h>

#include <atomic>
#include <string>

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int required = MultiByteToWideChar(
      CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
  if (required <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(required), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()),
                      wide.data(), required);
  return wide;
}

// Minimal COM IDropSource implementation for OLE DoDragDrop.
class SimpleDropSource final : public IDropSource {
 public:
  SimpleDropSource() : ref_count_(1) {}

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                           void** ppv_object) override {
    if (!ppv_object) {
      return E_POINTER;
    }
    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_IDropSource)) {
      *ppv_object = static_cast<IDropSource*>(this);
      AddRef();
      return S_OK;
    }
    *ppv_object = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override {
    return ++ref_count_;
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG count = --ref_count_;
    if (count == 0) {
      delete this;
    }
    return count;
  }

  HRESULT STDMETHODCALLTYPE QueryContinueDrag(BOOL escape_pressed,
                                              DWORD key_state) override {
    if (escape_pressed) {
      return DRAGDROP_S_CANCEL;
    }
    if ((key_state & MK_LBUTTON) == 0) {
      return DRAGDROP_S_DROP;
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE GiveFeedback(DWORD /*effect*/) override {
    return DRAGDROP_S_USEDEFAULTCURSORS;
  }

 private:
  ~SimpleDropSource() = default;
  std::atomic<ULONG> ref_count_;
};

}  // namespace

bool StartWindowsFileDrag(const std::string& utf8_path) {
  const std::wstring wide_path = Utf8ToWide(utf8_path);
  if (wide_path.empty()) {
    return false;
  }

  PIDLIST_ABSOLUTE pidl = nullptr;
  HRESULT hr = SHParseDisplayName(wide_path.c_str(), nullptr, &pidl, 0, nullptr);
  if (FAILED(hr) || pidl == nullptr) {
    return false;
  }

  IShellFolder* parent_folder = nullptr;
  PCUITEMID_CHILD child_pidl = nullptr;
  hr = SHBindToParent(pidl, IID_PPV_ARGS(&parent_folder), &child_pidl);
  if (FAILED(hr) || parent_folder == nullptr || child_pidl == nullptr) {
    CoTaskMemFree(pidl);
    return false;
  }

  IDataObject* data_object = nullptr;
  hr = parent_folder->GetUIObjectOf(
      nullptr, 1, &child_pidl, IID_IDataObject, nullptr,
      reinterpret_cast<void**>(&data_object));
  parent_folder->Release();
  CoTaskMemFree(pidl);

  if (FAILED(hr) || data_object == nullptr) {
    return false;
  }

  auto* drop_source = new SimpleDropSource();
  DWORD effect = DROPEFFECT_NONE;
  const HRESULT drag_result =
      DoDragDrop(data_object, drop_source, DROPEFFECT_COPY, &effect);

  drop_source->Release();
  data_object->Release();

  return drag_result == DRAGDROP_S_DROP && effect != DROPEFFECT_NONE;
}
