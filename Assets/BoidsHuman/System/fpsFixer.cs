using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class fpsFixer : MonoBehaviour
{
    void Start()
    {
        Application.targetFrameRate = 30;
    }
}
